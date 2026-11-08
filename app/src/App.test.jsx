import { render, screen } from '@testing-library/react';
import App from './App';
import { describe, test, expect } from 'bun:test';

describe('App', () => {
    test('renders photographer credit linking to portfolio', () => {
        render(<App />);

        const link = screen.getByRole('link', { name: /abelazo\.photography/i });
        expect(link.getAttribute('href')).toBe('https://abelazo.photography/?utm_source=cbtc-mediaday');
        expect(link.getAttribute('target')).toBe('_blank');
        expect(link.getAttribute('rel')).toContain('noopener');
        expect(screen.getByText(/Fotos: Abel Guillén/i)).toBeTruthy();
    });
});
