
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import DocumentIdForm from './DocumentIdForm';
import { describe, test, expect, vi } from 'bun:test';
import LanguageProvider from '../i18n/LanguageProvider';

// Intercepts only the first <a> created (the download link) so React-rendered anchors stay real.
function mockDownloadAnchor() {
    const mockLink = document.createElement('a');
    mockLink.click = vi.fn();
    const originalCreateElement = document.createElement.bind(document);
    let intercepted = false;
    document.createElement = vi.fn((tag, ...rest) => {
        if (tag === 'a' && !intercepted) {
            intercepted = true;
            return mockLink;
        }
        return originalCreateElement(tag, ...rest);
    });
    return { mockLink, restore: () => { document.createElement = originalCreateElement; } };
}

describe('DocumentIdForm', () => {
    test('renders form elements', () => {
        render(<DocumentIdForm />);

        // Use getByLabelText to encourage accessibility
        expect(screen.getByLabelText(/DNI, NIE/i)).toBeTruthy();
        expect(screen.getByLabelText(/Nombre completo/i)).toBeTruthy();
        expect(screen.getByRole('button', { name: /Enviar/i })).toBeTruthy();
    });

    test('updates values on change', () => {
        render(<DocumentIdForm />);

        const documentIdInput = screen.getByLabelText(/DNI, NIE/i);
        const nameInput = screen.getByLabelText(/Nombre completo/i);

        fireEvent.change(documentIdInput, { target: { value: '12345678A' } });
        fireEvent.change(nameInput, { target: { value: 'ValidUser' } });

        expect(documentIdInput.value).toBe('12345678A');
        expect(nameInput.value).toBe('ValidUser');
    });

    test('handles successful download', async () => {
        const fetchMock = vi.fn().mockResolvedValue({
            ok: true,
            json: async () => ({ download_url: 'https://s3.amazonaws.com/downloads/user.zip?signed', success: true })
        });
        global.fetch = fetchMock;

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
        const { mockLink, restore } = mockDownloadAnchor();
        const clickMock = mockLink.click;
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        await waitFor(() => {
            expect(fetchMock).toHaveBeenCalled();
        });

        await waitFor(() => {
            expect(document.createElement).toHaveBeenCalledWith('a');
            expect(mockLink.href).toBe('https://s3.amazonaws.com/downloads/user.zip?signed');
            expect(mockLink.download).toBe('user.zip');
            expect(clickMock).toHaveBeenCalled();
        });

        restore();
    });

    test('trims whitespace from documentId before encoding', async () => {
        const fetchMock = vi.fn().mockResolvedValue({
            ok: true,
            json: async () => ({ download_url: 'https://example.com/file.zip' })
        });
        global.fetch = fetchMock;

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: '  12345678A  ' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
        const { restore } = mockDownloadAnchor();
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        await waitFor(() => expect(fetchMock).toHaveBeenCalled());

        const authHeader = fetchMock.mock.calls[0][1].headers.Authorization;
        expect(authHeader).toBe(`Basic ${btoa('12345678A:user')}`);

        restore();
    });

    test('shows feedback link after successful download', async () => {
        global.fetch = vi.fn().mockResolvedValue({
            ok: true,
            json: async () => ({ download_url: 'https://example.com/file.zip' })
        });

        render(<DocumentIdForm />);

        expect(screen.queryByRole('link', { name: /formulario/i })).toBeNull();

        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
        const { restore } = mockDownloadAnchor();
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        const feedbackLink = await screen.findByRole('link', { name: /formulario/i });
        restore();
        expect(feedbackLink.getAttribute('href')).toBe('https://tally.so/r/Kpeyzz');
        expect(feedbackLink.getAttribute('target')).toBe('_blank');
        expect(feedbackLink.parentElement.textContent).toBe(
            '¿Qué te ha parecido? Puedes darme feedback en este formulario (en español).'
        );
        expect(screen.queryByText(/¿Te gustan\?/)).toBeNull();
    });

    test('does not show feedback link on error', async () => {
        global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 404 });

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        await screen.findByText(/No hay fotos asociadas/i);
        expect(screen.queryByRole('link', { name: /formulario/i })).toBeNull();
    });

    test('handles 404 error', async () => {
        const fetchMock = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
            text: async () => 'Not found'
        });
        global.fetch = fetchMock;

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        // Wait for async operations and state updates
        await waitFor(() => {
            expect(fetchMock).toHaveBeenCalled();
            expect(screen.getByText(/No hay fotos asociadas a este jugador/i)).toBeTruthy();
        });
    });

    test.each([401, 403])('shows friendly message on %i (invalid credentials)', async (status) => {
        global.fetch = vi.fn().mockResolvedValue({ ok: false, status, statusText: '' });

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: 'asdfa' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'asfdasd' } });
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        await waitFor(() => {
            expect(screen.getByText(/No se puede verificar que exista relación/i)).toBeTruthy();
        });
        expect(screen.queryByText(/Error \(\d+\)/)).toBeNull();
    });

    test('shows generic message on unexpected status with empty statusText', async () => {
        global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 500, statusText: '' });

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        await waitFor(() => {
            expect(screen.getByText(/Ha ocurrido un error inesperado/i)).toBeTruthy();
        });
        expect(screen.queryByText(/:\s*$/)).toBeNull();
    });
});

describe('DocumentIdForm translations', () => {
    const cases = {
        en: {
            name: /Player's full name/i,
            submit: /Submit/i,
            notFound: /No photos found for this player/,
            unauthorized: /couldn't match the document number/,
            unexpected: /An unexpected error occurred \(500\)/,
            feedback: /^form$/,
        },
        fr: {
            name: /Nom et prénom complets/i,
            submit: /Envoyer/i,
            notFound: /aucune photo associée/,
            unauthorized: /Impossible de vérifier la correspondance/,
            unexpected: /Une erreur inattendue s'est produite \(500\)/,
            feedback: /^formulaire$/,
        },
    };

    function submitIn(lang) {
        render(<LanguageProvider initialLang={lang}><DocumentIdForm /></LanguageProvider>);
        fireEvent.change(screen.getByLabelText(/DNI, NIE/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(cases[lang].name), { target: { value: 'User' } });
        fireEvent.click(screen.getByRole('button', { name: cases[lang].submit }));
    }

    test.each(['es', 'en', 'fr'])('%s: document field has no explanatory hint', (lang) => {
        render(<LanguageProvider initialLang={lang}><DocumentIdForm /></LanguageProvider>);
        expect(screen.getByLabelText(/DNI, NIE/i).hasAttribute('aria-describedby')).toBe(false);
    });

    test.each([
        ['en', 404, 'notFound'],
        ['fr', 404, 'notFound'],
        ['en', 401, 'unauthorized'],
        ['fr', 403, 'unauthorized'],
        ['en', 500, 'unexpected'],
        ['fr', 500, 'unexpected'],
    ])('%s: status %i shows translated %s message', async (lang, status, kind) => {
        global.fetch = vi.fn().mockResolvedValue({ ok: false, status, statusText: '' });
        submitIn(lang);
        expect(await screen.findByText(cases[lang][kind])).toBeTruthy();
    });

    test.each(['en', 'fr'])('%s: network failure shows translated unauthorized message', async (lang) => {
        global.fetch = vi.fn().mockRejectedValue(new Error('network'));
        const consoleError = console.error;
        console.error = () => {};
        submitIn(lang);
        expect(await screen.findByText(cases[lang].unauthorized)).toBeTruthy();
        console.error = consoleError;
    });

    test.each(['en', 'fr'])('%s: shows translated feedback link after success', async (lang) => {
        global.fetch = vi.fn().mockResolvedValue({
            ok: true,
            json: async () => ({ download_url: 'https://example.com/file.zip' }),
        });
        const { restore } = mockDownloadAnchor();
        submitIn(lang);
        const link = await screen.findByRole('link', { name: cases[lang].feedback });
        restore();
        expect(link.getAttribute('href')).toBe('https://tally.so/r/Kpeyzz');
    });
});
