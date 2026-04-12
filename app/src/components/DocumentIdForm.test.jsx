
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import DocumentIdForm from './DocumentIdForm';
import { describe, test, expect, vi } from 'bun:test';

describe('DocumentIdForm', () => {
    test('renders form elements', () => {
        render(<DocumentIdForm />);

        // Use getByLabelText to encourage accessibility
        expect(screen.getByLabelText(/Numero de Documento/i)).toBeTruthy();
        expect(screen.getByLabelText(/Nombre completo/i)).toBeTruthy();
        expect(screen.getByRole('button', { name: /Enviar/i })).toBeTruthy();
    });

    test('updates values on change', () => {
        render(<DocumentIdForm />);

        const documentIdInput = screen.getByLabelText(/Numero de Documento/i);
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

        const clickMock = vi.fn();
        const mockLink = document.createElement('a');
        mockLink.click = clickMock;

        const originalCreateElement = document.createElement.bind(document);
        document.createElement = vi.fn((tag) => {
            if (tag === 'a') {
                return mockLink;
            }
            return originalCreateElement(tag);
        });

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/Numero de Documento/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
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

        // Cleanup
        document.createElement = originalCreateElement;
    });

    test('handles 404 error', async () => {
        const fetchMock = vi.fn().mockResolvedValue({
            ok: false,
            status: 404,
            text: async () => 'Not found'
        });
        global.fetch = fetchMock;

        render(<DocumentIdForm />);

        fireEvent.change(screen.getByLabelText(/Numero de Documento/i), { target: { value: '123' } });
        fireEvent.change(screen.getByLabelText(/Nombre completo/i), { target: { value: 'User' } });
        fireEvent.click(screen.getByRole('button', { name: /Enviar/i }));

        // Wait for async operations and state updates
        await waitFor(() => {
            expect(fetchMock).toHaveBeenCalled();
            expect(screen.getByText(/No hay fotos asociadas a este jugador/i)).toBeTruthy();
        });
    });
});
