import { createElement, Fragment } from "react";
import es from "./locales/es";
import en from "./locales/en";
import fr from "./locales/fr";

export const SUPPORTED_LANGUAGES = ["es", "en", "fr"];
export const DEFAULT_LANGUAGE = "es";
export const STORAGE_KEY = "lang";
export const LANGUAGE_NAMES = { es: "Español", en: "English", fr: "Français" };
export const dictionaries = { es, en, fr };

function supported(code) {
  const base = String(code ?? "")
    .toLowerCase()
    .split("-")[0];
  return SUPPORTED_LANGUAGES.includes(base) ? base : null;
}

function readStorage(storage) {
  try {
    return storage?.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

// Order: ?lang= query param → stored user choice → browser languages → Spanish.
export function detectLanguage({
  search = globalThis.location?.search ?? "",
  storage = globalThis.localStorage,
  languages = globalThis.navigator?.languages ?? [globalThis.navigator?.language],
} = {}) {
  const candidates = [new URLSearchParams(search).get("lang"), readStorage(storage), ...(languages ?? [])];
  for (const candidate of candidates) {
    const lang = supported(candidate);
    if (lang) return lang;
  }
  return DEFAULT_LANGUAGE;
}

export function translate(lang, key, vars = {}) {
  const template = (dictionaries[lang] ?? dictionaries[DEFAULT_LANGUAGE])[key] ?? key;
  return template.replace(/\{(\w+)\}/g, (match, name) => (name in vars ? String(vars[name]) : match));
}

// Splits a template on {placeholders} and slots in React nodes (links, <strong>, ...).
export function interpolate(template, nodes = {}) {
  return template
    .split(/\{(\w+)\}/)
    .map((part, i) => createElement(Fragment, { key: i }, i % 2 ? (nodes[part] ?? `{${part}}`) : part));
}
