import React, { useState } from "react";
import { FEEDBACK_URL } from "../links";
import { useI18n } from "../i18n/I18nContext";

export default function DocumentIdForm() {
  const [documentId, setDocumentId] = useState("");
  const [name, setName] = useState("");
  const [message, setMessage] = useState(null);
  const { t, tRich } = useI18n();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage({ type: "info", key: "msg.processing" });

    try {
      const apiUrl = import.meta.env.VITE_API_URL || "";
      const normalizedName = name
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, "_");
      const credentials = `Basic ${btoa(`${documentId.trim()}:${normalizedName}`)}`;

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

        setMessage({ type: "success", key: "msg.success" });
      } else if (response.status === 404) {
        setMessage({ type: "error", key: "error.notFound", vars: { status: response.status } });
      } else if (response.status === 401 || response.status === 403) {
        setMessage({ type: "error", key: "error.unauthorized" });
      } else {
        setMessage({ type: "error", key: "error.unexpected", vars: { status: response.status } });
      }
    } catch (error) {
      console.error(error);
      setMessage({ type: "error", key: "error.unauthorized" });
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
        {tRich("form.note", {
          link: (
            <a
              href="https://cbtrescantos.es"
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: "inherit", fontWeight: "bold" }}
            >
              https://cbtrescantos.es
            </a>
          ),
        })}
      </p>
      <div style={{ marginBottom: "1rem" }}>
        <label htmlFor="name" style={{ display: "block", marginBottom: "0.5rem" }}>
          {t("form.name.label")}
        </label>
        <input
          id="name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder={t("form.name.placeholder")}
          style={{ padding: "0.5rem", width: "100%" }}
        />
      </div>
      <div style={{ marginBottom: "1rem" }}>
        <label htmlFor="documentId" style={{ display: "block", marginBottom: "0.5rem" }}>
          {t("form.doc.label")}
        </label>
        <input
          id="documentId"
          type="text"
          value={documentId}
          onChange={(e) => setDocumentId(e.target.value)}
          placeholder={t("form.doc.placeholder")}
          style={{ padding: "0.5rem", width: "100%" }}
        />
      </div>
      <button type="submit" disabled={!name.trim() || !documentId.trim()} style={{ padding: "0.5rem 1rem" }}>
        {t("form.submit")}
      </button>
      {message && (
        <div
          style={{
            marginTop: "1rem",
            color: message.type === "error" ? "red" : message.type === "success" ? "green" : "inherit",
          }}
        >
          {t(message.key, message.vars)}
        </div>
      )}
      {message?.type === "success" && (
        <div style={{ marginTop: "1rem", fontSize: "0.9em" }}>
          <p>
            {tRich("feedback.text", {
              feedback: <strong>{t("feedback.word")}</strong>,
              link: (
                <a
                  href={FEEDBACK_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: "inherit", fontWeight: "bold" }}
                >
                  {t("feedback.link")}
                </a>
              ),
            })}
          </p>
        </div>
      )}
    </form>
  );
}
