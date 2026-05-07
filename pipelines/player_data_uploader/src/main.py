import argparse
import glob
import logging
import os

import boto3
import pandas as pd

from .logger import get_logger

log_levels = {
    "FATAL": logging.FATAL,
    "ERROR": logging.ERROR,
    "WARNING": logging.WARNING,
    "INFO": logging.INFO,
    "DEBUG": logging.DEBUG,
}

logger = get_logger(__name__, level=log_levels[os.environ.get("PLAYERS_DATA_UPLOADER_LOG_LEVEL", "INFO").upper()])

DNI_COLUMNS = [
    "Player_DNI",
    "Player_NIE",
    "Player_Pasaporte",
    "Player_Tutor1DNI",
    "Player_Tutor1NIE",
    "Player_Tutor1Passport",
    "Player_Tutor2DNI",
    "Player_Tutor2NIE",
    "Player_Tutor2Passport",
]

TEAM_CODE_MAP = {
    "INCL": "Inclusion",
}


def resolve_team_dir_name(csv_team_code: str) -> str:
    """Map a CSV team code to its filesystem directory name."""
    return TEAM_CODE_MAP.get(csv_team_code, csv_team_code)


def parse_args(argv=None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Upload player data and photos")
    parser.add_argument("--team", type=str, default=None, help="Filter to a single team code")
    parser.add_argument("--photos-dir", type=str, default=None, help="Path to photos output directory")
    return parser.parse_args(argv)


def build_player_photo_mappings(photos_dir: str, team_dir_name: str, player_name: str) -> list[tuple[str, str]]:
    """Discover player photos and return (local_path, s3_key) tuples."""
    player_dir = os.path.join(photos_dir, team_dir_name, player_name)
    if not os.path.isdir(player_dir):
        logger.warning(f"Player photo directory not found: {player_dir}")
        return []

    pattern = os.path.join(player_dir, "*.jpg")
    files = sorted(glob.glob(pattern))
    return [(f, f"{player_name}/{os.path.basename(f)}") for f in files]


def build_team_photo_mappings(photos_dir: str, team_dir_name: str) -> list[tuple[str, str]]:
    """Discover team photos and return (local_path, s3_key) tuples."""
    teams_dir = os.path.join(photos_dir, "teams")
    if not os.path.isdir(teams_dir):
        logger.warning(f"Teams photo directory not found: {teams_dir}")
        return []

    pattern = os.path.join(teams_dir, f"{team_dir_name}.jpg")
    variant_pattern = os.path.join(teams_dir, f"{team_dir_name}-*.jpg")
    files = sorted(glob.glob(pattern) + glob.glob(variant_pattern))
    if not files:
        logger.warning(f"No team photos found for {team_dir_name}")
    return [(f, f"teams/{os.path.basename(f)}") for f in files]


def upload_files_to_s3(file_mappings: list[tuple[str, str]], bucket: str, s3_client=None) -> None:
    """Upload files to S3 from a list of (local_path, s3_key) tuples."""
    if s3_client is None:
        s3_client = boto3.client("s3")

    for local_path, s3_key in file_mappings:
        logger.debug(f"Uploading {local_path} -> s3://{bucket}/{s3_key}")
        s3_client.upload_file(local_path, bucket, s3_key)

    key_prefix = os.path.dirname(file_mappings[0][1]) + "/" if file_mappings else ""
    logger.info(f"Uploaded {len(file_mappings)} files to {key_prefix}")


def row_to_player_data(row: pd.Series, player_photo_keys: list[str], team_photo_keys: list[str]) -> dict:
    """Convert a DataFrame row to player data dictionary.

    Returns a dictionary with 'username', 'dnis', and 'photos' keys.
    Only non-null DNI values are included in the dnis list.
    """
    dnis = []
    for col in DNI_COLUMNS:
        value = row.get(col)
        if pd.notna(value) and str(value).strip() != "":
            dnis.append(str(value).strip())

    return {
        "username": row["CanonicalName"],
        "dnis": dnis,
        "photos": player_photo_keys + team_photo_keys,
    }


def upload_players_data(players_data: list[dict], table_name: str, dynamodb_resource=None) -> None:
    """Upload player data items to DynamoDB users table."""
    if dynamodb_resource is None:
        dynamodb_resource = boto3.resource("dynamodb")

    table = dynamodb_resource.Table(table_name)

    with table.batch_writer() as batch:
        for player in players_data:
            batch.put_item(Item=player)

    logger.info(f"Uploaded {len(players_data)} items to {table_name}")


def main(argv=None):
    logger.info("Starting players data uploader pipeline")

    args = parse_args(argv)

    input_path = os.environ.get("CBTC_MEDIA_DAY_OUTPUT_PATH", "output/cbtc_media_day_players.csv")
    table_name = os.environ.get("CBTC_PLAYERS_TABLE_NAME", "players")
    photos_bucket = os.environ.get("CBTC_PHOTOS_BUCKET")
    photos_dir = args.photos_dir or os.environ.get("CBTC_PHOTOS_DIR", "")

    logger.info(f"Reading CSV from {input_path}")
    df = pd.read_csv(input_path, encoding="utf-8")
    logger.info(f"Loaded {len(df)} rows from CSV")

    if args.team:
        df = df[df["Equipo"] == args.team]
        logger.info(f"Filtered to team {args.team}: {len(df)} rows")

    if photos_bucket:
        logger.info(f"Photos bucket: {photos_bucket}")
    s3_client = boto3.client("s3") if photos_bucket else None

    uploaded_teams: set[str] = set()
    team_photo_keys_cache: dict[str, list[str]] = {}
    players_data = []

    for _, row in df.iterrows():
        team_code = row["Equipo"]
        team_dir_name = resolve_team_dir_name(team_code)
        player_name = row["CanonicalName"]

        if team_dir_name not in uploaded_teams:
            team_mappings = build_team_photo_mappings(photos_dir, team_dir_name)
            if s3_client and team_mappings:
                upload_files_to_s3(team_mappings, photos_bucket, s3_client)
            team_photo_keys_cache[team_dir_name] = [s3_key for _, s3_key in team_mappings]
            uploaded_teams.add(team_dir_name)

        player_mappings = build_player_photo_mappings(photos_dir, team_dir_name, player_name)
        if s3_client and player_mappings:
            upload_files_to_s3(player_mappings, photos_bucket, s3_client)

        player_photo_keys = [s3_key for _, s3_key in player_mappings]
        team_photo_keys = team_photo_keys_cache.get(team_dir_name, [])

        player_data = row_to_player_data(row, player_photo_keys, team_photo_keys)
        players_data.append(player_data)

    logger.info(f"Uploading {len(players_data)} players to DynamoDB table '{table_name}'")
    upload_players_data(players_data, table_name)


if __name__ == "__main__":
    main()
