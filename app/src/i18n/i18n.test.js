import { describe, test, expect } from 'bun:test';
import { isValidElement } from 'react';
import { detectLanguage, translate, interpolate, dictionaries, SUPPORTED_LANGUAGES } from './i18n';

function memoryStorage(initial = {}) {
    const data = { ...initial };
    return {
        getItem: (k) => (k in data ? data[k] : null),
        setItem: (k, v) => { data[k] = String(v); },
    };
}

describe('dictionaries', () => {
    test('supports es, en and fr', () => {
        expect(SUPPORTED_LANGUAGES).toEqual(['es', 'en', 'fr']);
    });

    test.each(['en', 'fr'])('%s has exactly the same keys as es', (lang) => {
        expect(Object.keys(dictionaries[lang]).sort()).toEqual(Object.keys(dictionaries.es).sort());
    });

    test.each(['es', 'en', 'fr'])('%s has no empty values', (lang) => {
        const empty = Object.entries(dictionaries[lang]).filter(([, v]) => !v).map(([k]) => k);
        expect(empty).toEqual([]);
    });

    test.each(['es', 'en', 'fr'])('%s keeps the DNI and NIE terms in the document label', (lang) => {
        expect(dictionaries[lang]['form.doc.label']).toMatch(/^DNI, NIE/);
    });
});

describe('detectLanguage', () => {
    test('query parameter wins over storage and browser', () => {
        const lang = detectLanguage({
            search: '?lang=fr',
            storage: memoryStorage({ lang: 'en' }),
            languages: ['es-ES'],
        });
        expect(lang).toBe('fr');
    });

    test('stored choice wins over browser', () => {
        expect(detectLanguage({ search: '', storage: memoryStorage({ lang: 'en' }), languages: ['fr-FR'] })).toBe('en');
    });

    test('uses first supported browser language, matching on prefix', () => {
        expect(detectLanguage({ search: '', storage: memoryStorage(), languages: ['de-DE', 'fr-CA', 'en'] })).toBe('fr');
    });

    test('falls back to es when nothing matches', () => {
        expect(detectLanguage({ search: '', storage: memoryStorage(), languages: ['de-DE'] })).toBe('es');
    });

    test('ignores unsupported query parameter and stored values', () => {
        expect(
            detectLanguage({ search: '?lang=xx', storage: memoryStorage({ lang: 'zz' }), languages: ['EN-gb'] })
        ).toBe('en');
    });

    test('survives storage that throws', () => {
        const storage = { getItem: () => { throw new Error('blocked'); } };
        expect(detectLanguage({ search: '', storage, languages: ['fr'] })).toBe('fr');
    });
});

describe('translate', () => {
    test('substitutes variables', () => {
        expect(translate('en', 'error.unexpected', { status: 500 })).toContain('(500)');
    });

    test('falls back to es for unknown language', () => {
        expect(translate('xx', 'form.submit')).toBe('Enviar');
    });

    test('returns the key when missing', () => {
        expect(translate('en', 'does.not.exist')).toBe('does.not.exist');
    });
});

describe('interpolate', () => {
    test('replaces placeholders with nodes, keeping surrounding text', () => {
        const parts = interpolate('a {x} b', { x: 'X' });
        expect(parts.every(isValidElement)).toBe(true);
        expect(parts.map((p) => p.props.children).join('')).toBe('a X b');
    });
});
