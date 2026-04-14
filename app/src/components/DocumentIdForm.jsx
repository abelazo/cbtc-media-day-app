import React, { useState } from "react";

export default function DocumentIdForm() {
  const [documentId, setDocumentId] = useState("");
  const [name, setName] = useState("");
  const [message, setMessage] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage({ type: "info", text: "Procesando..." });

    try {
      const apiUrl = import.meta.env.VITE_API_URL || "";
      const normalizedName = name
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, "_");
      const credentials = `Basic ${btoa(`${documentId}:${normalizedName}`)}`;

      const response = await fetch(`${apiUrl}/content`, {
        headers: {
          Authorization: credentials,
        },
      });

      if (response.ok) {
        const data = await response.json();
        const link = document.createElement("a");
        link.href = data.download_url;
        link.download = `${normalizedName}.zip`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        setMessage({ type: "success", text: "✅ ¡Descarga completada! Revisa tu carpeta de descargas." });
      } else if (response.status === 404) {
        setMessage({
          type: "error",
          text: "❌ Error (" + response.status + ") : No hay fotos asociadas a este jugador",
        });
      } else {
        setMessage({ type: "error", text: "❌ Error (" + response.status + ") : " + response.statusText });
      }
    } catch (error) {
      console.error(error);
      setMessage({
        type: "error",
        text: "❌ No se puede verificar que exista relación entre el número de documento y el nombre de jugador/a proporcionados",
      });
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <p
        style={{
          fontSize: "0.85em",
          fontStyle: "italic",
          marginBottom: "1.5rem",
          backgroundColor: "rgba(255, 255, 255, 0.15)",
          padding: "0.5rem 1rem",
          borderRadius: "0.5rem",
          borderLeft: "3px solid rgba(255, 255, 255, 0.5)",
        }}
      >
        Datos según lo registrado en{" "}
        <a
          href="https://cbtrescantos.es"
          target="_blank"
          rel="noopener noreferrer"
          style={{ color: "inherit", fontWeight: "bold" }}
        >
          https://cbtrescantos.es
        </a>
      </p>
      <div style={{ marginBottom: "1rem" }}>
        <label htmlFor="name" style={{ display: "block", marginBottom: "0.5rem" }}>
          Nombre completo y apellidos del jugador/a
        </label>
        <input
          id="name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Ej: Juan Pérez García"
          style={{ padding: "0.5rem", width: "100%" }}
        />
      </div>
      <div style={{ marginBottom: "1rem" }}>
        <label htmlFor="documentId" style={{ display: "block", marginBottom: "0.5rem" }}>
          DNI, NIE o Pasaporte del jugador o tutores asociados
        </label>
        <input
          id="documentId"
          type="text"
          value={documentId}
          onChange={(e) => setDocumentId(e.target.value)}
          placeholder="Ej: 03378357W, Y9777800P, DSA136567J"
          style={{ padding: "0.5rem", width: "100%" }}
        />
      </div>
      <button type="submit" disabled={!name.trim() || !documentId.trim()} style={{ padding: "0.5rem 1rem" }}>
        Enviar
      </button>
      {message && (
        <div
          style={{
            marginTop: "1rem",
            color: message.type === "error" ? "red" : message.type === "success" ? "green" : "inherit",
          }}
        >
          {message.text}
        </div>
      )}
    </form>
  );
}
