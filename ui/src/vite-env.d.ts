/// <reference types="vite/client" />
interface ImportMetaEnv {
  readonly VITE_DATA_URL: string;
  readonly VITE_HTML_TITLE: string;
}
interface ImportMeta {
  readonly env: ImportMetaEnv;
}
