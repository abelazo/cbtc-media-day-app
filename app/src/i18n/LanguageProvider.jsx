import { useEffect, useMemo, useState } from "react";
import { I18nContext, createI18nValue } from "./I18nContext";
import { STORAGE_KEY, detectLanguage } from "./i18n";

export default function LanguageProvider({ initialLang, children }) {
  const [lang, setLangState] = useState(() => initialLang ?? detectLanguage());

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const value = useMemo(() => {
    const setLang = (next) => {
      setLangState(next);
      try {
        localStorage.setItem(STORAGE_KEY, next);
      } catch {
        // Storage blocked (private mode): choice lasts for this page view only.
      }
    };
    return createI18nValue(lang, setLang);
  }, [lang]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}
