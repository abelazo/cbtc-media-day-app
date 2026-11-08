import { useI18n } from "./I18nContext";
import { LANGUAGE_NAMES, SUPPORTED_LANGUAGES } from "./i18n";
import { EsFlag, FrFlag, GbFlag } from "./flags";

const FLAGS = { es: EsFlag, en: GbFlag, fr: FrFlag };

export default function LanguageSwitcher() {
  const { lang, setLang, t } = useI18n();

  return (
    <div role="group" aria-label={t("lang.group")} style={{ display: "flex", justifyContent: "flex-end", gap: "0.25rem" }}>
      {SUPPORTED_LANGUAGES.map((code) => {
        const Flag = FLAGS[code];
        const active = code === lang;
        return (
          <button
            key={code}
            type="button"
            aria-label={LANGUAGE_NAMES[code]}
            aria-pressed={active}
            title={LANGUAGE_NAMES[code]}
            onClick={() => setLang(code)}
            style={{
              minWidth: 44,
              minHeight: 44,
              padding: "0.5rem",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              background: "transparent",
              border: active ? "2px solid currentColor" : "2px solid transparent",
              borderRadius: "0.5rem",
              opacity: active ? 1 : 0.55,
              cursor: "pointer",
            }}
          >
            <Flag />
          </button>
        );
      })}
    </div>
  );
}
