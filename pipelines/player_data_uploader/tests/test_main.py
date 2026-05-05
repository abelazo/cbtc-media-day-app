import os
from unittest.mock import MagicMock

import pandas as pd
from src.main import (
    DNI_COLUMNS,
    TEAM_CODE_MAP,
    build_player_photo_mappings,
    build_team_photo_mappings,
    parse_args,
    resolve_team_dir_name,
    row_to_player_data,
    upload_files_to_s3,
    upload_players_data,
)


class TestResolveTeamDirName:
    def test_mapped_codes(self):
        assert resolve_team_dir_name("FAU") == "FAUT"
        assert resolve_team_dir_name("MAU") == "MAUT"
        assert resolve_team_dir_name("INCL") == "Inclusion"

    def test_unmapped_codes_return_as_is(self):
        assert resolve_team_dir_name("MA1A") == "MA1A"
        assert resolve_team_dir_name("MU22") == "MU22"
        assert resolve_team_dir_name("FCA") == "FCA"
        assert resolve_team_dir_name("MJB") == "MJB"

    def test_map_has_expected_entries(self):
        assert TEAM_CODE_MAP == {"FAU": "FAUT", "MAU": "MAUT", "INCL": "Inclusion"}


class TestParseArgs:
    def test_no_arguments(self):
        args = parse_args([])
        assert args.team is None
        assert args.photos_dir is None

    def test_team_argument(self):
        args = parse_args(["--team", "MA1A"])
        assert args.team == "MA1A"

    def test_photos_dir_argument(self):
        args = parse_args(["--photos-dir", "/some/path"])
        assert args.photos_dir == "/some/path"

    def test_all_arguments(self):
        args = parse_args(["--team", "FCA", "--photos-dir", "/photos"])
        assert args.team == "FCA"
        assert args.photos_dir == "/photos"


class TestBuildPlayerPhotoMappings:
    def test_discovers_photos(self, tmp_path):
        player_dir = tmp_path / "MA1A" / "juan_garcia"
        player_dir.mkdir(parents=True)
        (player_dir / "juan_garcia.jpg").write_bytes(b"img1")
        (player_dir / "juan_garcia-2.jpg").write_bytes(b"img2")
        (player_dir / "juan_garcia-3.jpg").write_bytes(b"img3")

        result = build_player_photo_mappings(str(tmp_path), "MA1A", "juan_garcia")

        assert len(result) == 3
        assert result[0] == (str(player_dir / "juan_garcia-2.jpg"), "juan_garcia/juan_garcia-2.jpg")
        assert result[1] == (str(player_dir / "juan_garcia-3.jpg"), "juan_garcia/juan_garcia-3.jpg")
        assert result[2] == (str(player_dir / "juan_garcia.jpg"), "juan_garcia/juan_garcia.jpg")

    def test_missing_directory_returns_empty(self, tmp_path):
        result = build_player_photo_mappings(str(tmp_path), "MA1A", "nonexistent_player")
        assert result == []

    def test_no_jpg_files_returns_empty(self, tmp_path):
        player_dir = tmp_path / "MA1A" / "juan_garcia"
        player_dir.mkdir(parents=True)
        (player_dir / "readme.txt").write_text("not a photo")

        result = build_player_photo_mappings(str(tmp_path), "MA1A", "juan_garcia")
        assert result == []

    def test_results_are_sorted(self, tmp_path):
        player_dir = tmp_path / "FCA" / "maria_lopez"
        player_dir.mkdir(parents=True)
        (player_dir / "maria_lopez-4.jpg").write_bytes(b"img")
        (player_dir / "maria_lopez.jpg").write_bytes(b"img")
        (player_dir / "maria_lopez-2.jpg").write_bytes(b"img")

        result = build_player_photo_mappings(str(tmp_path), "FCA", "maria_lopez")

        filenames = [os.path.basename(local) for local, _ in result]
        assert filenames == ["maria_lopez-2.jpg", "maria_lopez-4.jpg", "maria_lopez.jpg"]


class TestBuildTeamPhotoMappings:
    def test_discovers_team_photos(self, tmp_path):
        teams_dir = tmp_path / "teams"
        teams_dir.mkdir()
        (teams_dir / "MA1A.jpg").write_bytes(b"img1")
        (teams_dir / "MA1A-2.jpg").write_bytes(b"img2")

        result = build_team_photo_mappings(str(tmp_path), "MA1A")

        assert len(result) == 2
        assert result[0] == (str(teams_dir / "MA1A-2.jpg"), "teams/MA1A-2.jpg")
        assert result[1] == (str(teams_dir / "MA1A.jpg"), "teams/MA1A.jpg")

    def test_no_matching_photos_returns_empty(self, tmp_path):
        teams_dir = tmp_path / "teams"
        teams_dir.mkdir()
        (teams_dir / "OTHER.jpg").write_bytes(b"img")

        result = build_team_photo_mappings(str(tmp_path), "MA1A")
        assert result == []

    def test_missing_teams_dir_returns_empty(self, tmp_path):
        result = build_team_photo_mappings(str(tmp_path), "MA1A")
        assert result == []

    def test_does_not_match_partial_names(self, tmp_path):
        teams_dir = tmp_path / "teams"
        teams_dir.mkdir()
        (teams_dir / "MA1A.jpg").write_bytes(b"img")
        (teams_dir / "MA1AB.jpg").write_bytes(b"should not match")

        result = build_team_photo_mappings(str(tmp_path), "MA1A")

        assert len(result) == 1
        assert result[0][1] == "teams/MA1A.jpg"


class TestUploadFilesToS3:
    def test_uploads_all_files(self):
        mock_s3 = MagicMock()
        mappings = [
            ("/photos/player/a.jpg", "player/a.jpg"),
            ("/photos/player/b.jpg", "player/b.jpg"),
        ]

        upload_files_to_s3(mappings, "my-bucket", s3_client=mock_s3)

        assert mock_s3.upload_file.call_count == 2
        mock_s3.upload_file.assert_any_call("/photos/player/a.jpg", "my-bucket", "player/a.jpg")
        mock_s3.upload_file.assert_any_call("/photos/player/b.jpg", "my-bucket", "player/b.jpg")

    def test_empty_mappings_no_upload(self):
        mock_s3 = MagicMock()
        upload_files_to_s3([], "my-bucket", s3_client=mock_s3)
        mock_s3.upload_file.assert_not_called()

    def test_correct_bucket_and_keys(self):
        mock_s3 = MagicMock()
        mappings = [("/local/teams/MA1A.jpg", "teams/MA1A.jpg")]

        upload_files_to_s3(mappings, "photo-bucket", s3_client=mock_s3)

        mock_s3.upload_file.assert_called_once_with("/local/teams/MA1A.jpg", "photo-bucket", "teams/MA1A.jpg")


class TestRowToPlayerData:
    def test_all_dnis_present(self):
        row = pd.Series(
            {
                "CanonicalName": "juan_garcia",
                "Equipo": "Infantil A",
                "Player_DNI": "12345678Z",
                "Player_NIE": "X1234567A",
                "Player_Pasaporte": "AAA123456",
                "Player_Tutor1DNI": "11111111H",
                "Player_Tutor1NIE": "Y1111111B",
                "Player_Tutor1Passport": "BBB111111",
                "Player_Tutor2DNI": "22222222J",
                "Player_Tutor2NIE": "Z2222222C",
                "Player_Tutor2Passport": "CCC222222",
            }
        )
        player_photos = ["juan_garcia/juan_garcia.jpg", "juan_garcia/juan_garcia-2.jpg"]
        team_photos = ["teams/Infantil A.jpg"]

        result = row_to_player_data(row, player_photos, team_photos)

        assert result["username"] == "juan_garcia"
        assert len(result["dnis"]) == 9
        assert "12345678Z" in result["dnis"]
        assert "X1234567A" in result["dnis"]
        assert "AAA123456" in result["dnis"]
        assert result["photos"] == player_photos + team_photos

    def test_some_dnis_null(self):
        row = pd.Series(
            {
                "CanonicalName": "maria_lopez",
                "Equipo": "Alevin B",
                "Player_DNI": "12345678Z",
                "Player_NIE": None,
                "Player_Pasaporte": "",
                "Player_Tutor1DNI": "11111111H",
                "Player_Tutor1NIE": None,
                "Player_Tutor1Passport": None,
                "Player_Tutor2DNI": None,
                "Player_Tutor2NIE": None,
                "Player_Tutor2Passport": None,
            }
        )
        result = row_to_player_data(row, ["maria_lopez/maria_lopez.jpg"], ["teams/Alevin B.jpg"])

        assert result["username"] == "maria_lopez"
        assert len(result["dnis"]) == 2
        assert "12345678Z" in result["dnis"]
        assert "11111111H" in result["dnis"]
        assert result["photos"] == ["maria_lopez/maria_lopez.jpg", "teams/Alevin B.jpg"]

    def test_no_dnis(self):
        row = pd.Series(
            {
                "CanonicalName": "pedro_sanchez",
                "Equipo": "Cadete",
                "Player_DNI": None,
                "Player_NIE": None,
                "Player_Pasaporte": None,
                "Player_Tutor1DNI": None,
                "Player_Tutor1NIE": None,
                "Player_Tutor1Passport": None,
                "Player_Tutor2DNI": None,
                "Player_Tutor2NIE": None,
                "Player_Tutor2Passport": None,
            }
        )
        result = row_to_player_data(row, [], [])

        assert result["username"] == "pedro_sanchez"
        assert result["dnis"] == []
        assert result["photos"] == []

    def test_whitespace_only_dnis_excluded(self):
        row = pd.Series(
            {
                "CanonicalName": "ana_martinez",
                "Equipo": "Junior",
                "Player_DNI": "12345678Z",
                "Player_NIE": "   ",
                "Player_Pasaporte": None,
                "Player_Tutor1DNI": None,
                "Player_Tutor1NIE": None,
                "Player_Tutor1Passport": None,
                "Player_Tutor2DNI": None,
                "Player_Tutor2NIE": None,
                "Player_Tutor2Passport": None,
            }
        )
        result = row_to_player_data(row, [], [])

        assert len(result["dnis"]) == 1
        assert "12345678Z" in result["dnis"]

    def test_dnis_are_stripped(self):
        row = pd.Series(
            {
                "CanonicalName": "carlos_ruiz",
                "Equipo": "Senior",
                "Player_DNI": "  12345678Z  ",
                "Player_NIE": None,
                "Player_Pasaporte": None,
                "Player_Tutor1DNI": None,
                "Player_Tutor1NIE": None,
                "Player_Tutor1Passport": None,
                "Player_Tutor2DNI": None,
                "Player_Tutor2NIE": None,
                "Player_Tutor2Passport": None,
            }
        )
        result = row_to_player_data(row, [], [])

        assert result["dnis"] == ["12345678Z"]

    def test_photos_are_combined(self):
        row = pd.Series(
            {
                "CanonicalName": "luis_fernandez",
                "Equipo": "Prebenjamin",
                "Player_DNI": "12345678Z",
                "Player_NIE": None,
                "Player_Pasaporte": None,
                "Player_Tutor1DNI": None,
                "Player_Tutor1NIE": None,
                "Player_Tutor1Passport": None,
                "Player_Tutor2DNI": None,
                "Player_Tutor2NIE": None,
                "Player_Tutor2Passport": None,
            }
        )
        player_photos = ["luis_fernandez/luis_fernandez.jpg", "luis_fernandez/luis_fernandez-2.jpg"]
        team_photos = ["teams/Prebenjamin.jpg", "teams/Prebenjamin-2.jpg"]

        result = row_to_player_data(row, player_photos, team_photos)

        assert result["photos"] == [
            "luis_fernandez/luis_fernandez.jpg",
            "luis_fernandez/luis_fernandez-2.jpg",
            "teams/Prebenjamin.jpg",
            "teams/Prebenjamin-2.jpg",
        ]


class TestUploadPlayersData:
    def test_uploads_all_players(self):
        mock_dynamodb = MagicMock()
        mock_table = MagicMock()
        mock_batch_writer = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_table.batch_writer.return_value.__enter__ = MagicMock(return_value=mock_batch_writer)
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        players_data = [
            {
                "username": "player1",
                "dnis": ["11111111H"],
                "photos": ["player1/player1.jpg", "teams/Team A.jpg"],
            },
            {
                "username": "player2",
                "dnis": ["22222222J", "X1234567A"],
                "photos": ["player2/player2.jpg", "teams/Team B.jpg"],
            },
        ]

        upload_players_data(players_data, "users", dynamodb_resource=mock_dynamodb)

        mock_dynamodb.Table.assert_called_once_with("users")
        assert mock_batch_writer.put_item.call_count == 2
        mock_batch_writer.put_item.assert_any_call(Item=players_data[0])
        mock_batch_writer.put_item.assert_any_call(Item=players_data[1])

    def test_uploads_empty_list(self):
        mock_dynamodb = MagicMock()
        mock_table = MagicMock()
        mock_batch_writer = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_table.batch_writer.return_value.__enter__ = MagicMock(return_value=mock_batch_writer)
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        upload_players_data([], "users", dynamodb_resource=mock_dynamodb)

        mock_batch_writer.put_item.assert_not_called()

    def test_uses_correct_table_name(self):
        mock_dynamodb = MagicMock()
        mock_table = MagicMock()
        mock_batch_writer = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_table.batch_writer.return_value.__enter__ = MagicMock(return_value=mock_batch_writer)
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        upload_players_data([], "my_custom_table", dynamodb_resource=mock_dynamodb)

        mock_dynamodb.Table.assert_called_once_with("my_custom_table")


class TestDniColumns:
    def test_dni_columns_order(self):
        expected = [
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
        assert DNI_COLUMNS == expected
