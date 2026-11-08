import { render, screen, fireEvent } from '@testing-library/react';
import { describe, test, expect, beforeEach } from 'bun:test';
import App from '../App';
import LanguageProvider from './LanguageProvider';

describe('LanguageSwitcher', () => {
    beforeEach(() => {
        try { localStorage.clear(); } catch { /* ignore */ }
    });

    test('renders one flag button per language, marking the active one', () => {
        render(<LanguageProvider initialLang="en"><App /></LanguageProvider>);

        const group = screen.getByRole('group', { name: 'Language' });
        expect(group).toBeTruthy();
        expect(screen.getByRole('button', { name: 'Español' }).getAttribute('aria-pressed')).toBe('false');
        expect(screen.getByRole('button', { name: 'English' }).getAttribute('aria-pressed')).toBe('true');
        expect(screen.getByRole('button', { name: 'Français' }).getAttribute('aria-pressed')).toBe('false');
    });

    test('switching language re-renders texts, persists choice and sets html lang', () => {
        render(<LanguageProvider initialLang="es"><App /></LanguageProvider>);
        expect(screen.getByRole('button', { name: /Enviar/i })).toBeTruthy();

        fireEvent.click(screen.getByRole('button', { name: 'Français' }));

        expect(screen.getByRole('button', { name: /Envoyer/i })).toBeTruthy();
        expect(screen.getByRole('button', { name: 'Français' }).getAttribute('aria-pressed')).toBe('true');
        expect(localStorage.getItem('lang')).toBe('fr');
        expect(document.documentElement.lang).toBe('fr');
    });

    test('translates footer credit', () => {
        render(<LanguageProvider initialLang="en"><App /></LanguageProvider>);
        expect(screen.getByText(/Photos: Abel Guillén/i)).toBeTruthy();
    });
});
