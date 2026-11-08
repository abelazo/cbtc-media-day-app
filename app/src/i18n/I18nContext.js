import { createContext, useContext } from "react";
import { DEFAULT_LANGUAGE, dictionaries, interpolate, translate } from "./i18n";

export function createI18nValue(lang, setLang = () => {}) {
  return {
    lang,
    setLang,
    t: (key, vars) => translate(lang, key, vars),
    tRich: (key, nodes) => interpolate(dictionaries[lang][key], nodes),
  };
}

// Without a provider (e.g. isolated component tests) components render in Spanish.
export const I18nContext = createContext(createI18nValue(DEFAULT_LANGUAGE));

export function useI18n() {
  return useContext(I18nContext);
}
