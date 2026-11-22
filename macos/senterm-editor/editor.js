import * as monaco from 'monaco-editor/esm/vs/editor/editor.api.js';
import 'monaco-editor/esm/vs/editor/browser/widget/diffEditor/diffEditor.contribution.js';
import 'monaco-editor/esm/vs/editor/contrib/find/browser/findController.js';
import 'monaco-editor/esm/vs/base/browser/ui/codicons/codicon/codicon.css';
import { createHighlighterCore } from 'shiki/core';
import { createOnigurumaEngine } from 'shiki/engine/oniguruma';
import wasm from 'shiki/wasm';
import { shikiToMonaco } from '@shikijs/monaco';
import vscodeTheme from './2026-dark.json';
import grammars from 'senterm-grammars';

const theme = { ...vscodeTheme, name: 'vscode-2026-dark' };

const languages = {
  js: 'javascript', jsx: 'jsx', ts: 'typescript', tsx: 'tsx', py: 'python',
  swift: 'swift', zig: 'zig', zon: 'zig', go: 'go', rs: 'rust', toml: 'toml',
  yaml: 'yaml', yml: 'yaml', json: 'json', jsonc: 'jsonc', md: 'markdown',
  sh: 'shellscript', bash: 'shellscript', zsh: 'shellscript', html: 'html',
  css: 'css', sql: 'sql', c: 'c', h: 'c', cpp: 'cpp', hpp: 'cpp',
  java: 'java', rb: 'ruby', diff: 'diff',
};
const languageIds = [...new Set(Object.values(languages))];
for (const id of languageIds) monaco.languages.register({ id });
monaco.editor.defineTheme(theme.name, { base: 'vs-dark', inherit: true, rules: [], colors: theme.colors });
const highlighting = createHighlighterCore({ themes: [theme], langs: grammars, engine: createOnigurumaEngine(wasm) })
  .then(highlighter => shikiToMonaco(highlighter, monaco))
  .catch(error => console.error('syntax highlighting unavailable', error));

const $ = id => document.getElementById(id);
const bridge = window.webkit.messageHandlers.review;
const worker = URL.createObjectURL(new Blob([EDITOR_WORKER], { type: 'text/javascript' }));
self.MonacoEnvironment = { getWorker: () => new Worker(worker) };
const editor = monaco.editor.createDiffEditor($('editor'), {
  theme: theme.name, readOnly: true, originalEditable: false,
  automaticLayout: true, renderSideBySide: true, useInlineViewWhenSpaceIsLimited: false,
  renderMarginRevertIcon: false, renderGutterMenu: false, renderIndicators: true,
  diffAlgorithm: 'advanced', ignoreTrimWhitespace: false,
  fontSize: 16, lineHeight: 24, fontFamily: 'Menlo, Monaco, monospace',
  minimap: { enabled: false }, padding: { top: 0 }, scrollBeyondLastLine: false,
  glyphMargin: false, folding: false, renderWhitespace: 'selection', links: false,
  scrollbar: { verticalScrollbarSize: 14, horizontalScrollbarSize: 10 },
});
let scope = 'unstaged';
let selection;
let sequence = 0;
function clearEditor() {
  const old = editor.getModel();
  editor.setModel(null);
  old?.original.dispose();
  old?.modified.dispose();
  $('next').disabled = $('previous').disabled = true;
}
function message(text) {
  $('message').textContent = text;
  $('message').hidden = !text;
}
function request(action, extra = {}) {
  const id = ++sequence;
  bridge.postMessage({ action, scope, id, ...extra });
}
function list() {
  selection = undefined;
  clearEditor();
  $('tab').hidden = $('breadcrumb').hidden = true;
  $('language').textContent = '';
  $('count').textContent = $('activity-count').textContent = '';
  $('count').hidden = $('activity-count').hidden = true;
  $('stats').textContent = '';
  $('files').replaceChildren();
  message('reading git changes…');
  request('list');
}
function nameParts(path) {
  const index = path.lastIndexOf('/');
  return [path.slice(index + 1), index < 0 ? '' : path.slice(0, index)];
}
function select(file) {
  selection = file;
  const [name, folder] = nameParts(file.path);
  for (const row of $('files').children) row.setAttribute('aria-current', String(row.title === file.path));
  $('tab-title').textContent = `${name} (${scope === 'staged' ? 'Index' : 'Working Tree'})`;
  $('tab-title').title = file.path;
  $('tab-status').textContent = $('tab-status').dataset.status = file.status;
  $('breadcrumb').querySelector('span').textContent = folder ? `${folder.replaceAll('/', '  ›  ')}  ›  ${name}` : name;
  $('tab').hidden = $('breadcrumb').hidden = false;
  clearEditor();
  $('language').textContent = '';
  message('reading file…');
  request('file', { path: file.path });
}
window.renderReview = async response => {
  if (response.id !== sequence) return;
  if (response.error) { message(response.error); return; }
  if (response.list) {
    const { files, revision, additions, deletions } = response.list;
    $('count').textContent = $('activity-count').textContent = files.length;
    $('count').hidden = $('activity-count').hidden = files.length === 0;
    $('branch').textContent = revision ?? '';
    $('stats').textContent = `${files.length} ${files.length === 1 ? 'file' : 'files'}` +
      (additions == null ? ' · line totals unavailable' : `   +${additions}  −${deletions}`);
    for (const file of files) {
      const [name, folder] = nameParts(file.path);
      const row = document.createElement('button');
      row.className = 'file';
      row.title = file.path;
      const icon = document.createElement('i'); icon.className = 'codicon codicon-file-code';
      const label = document.createElement('span'); label.className = 'name'; label.textContent = name;
      const parent = document.createElement('span'); parent.className = 'folder'; parent.textContent = folder;
      const status = document.createElement('span'); status.className = 'status';
      status.textContent = status.dataset.status = file.status === '?' ? 'U' : file.status;
      row.append(icon, label, parent, status);
      row.onclick = () => select(file);
      $('files').append(row);
    }
    if (files.length) select(files[0]);
    else message(`no ${scope} changes`);
    return;
  }
  await highlighting;
  if (response.id !== sequence || !response.comparison || !selection) return;
  const [name] = nameParts(selection.path);
  const language = languages[name.split('.').at(-1).toLowerCase()] ?? 'plaintext';
  $('language').textContent = /(?:^\.git|ignore$)/.test(name) ? 'Ignore' : language;
  const { original, modified } = response.comparison;
  editor.setModel({ original: monaco.editor.createModel(original, language), modified: monaco.editor.createModel(modified, language) });
  editor.layout();
  renderPanes();
  message(original === modified ? 'no textual changes' : '');
};
function renderPanes() {
  editor.getOriginalEditor().render(true);
  editor.getModifiedEditor().render(true);
}
editor.onDidUpdateDiff(() => {
  renderPanes();
  const hasChanges = (editor.getLineChanges()?.length ?? 0) > 0;
  $('next').disabled = $('previous').disabled = !hasChanges;
});
$('next').onclick = () => editor.goToDiff('next');
$('previous').onclick = () => editor.goToDiff('previous');
$('refresh').onclick = list;
for (const button of document.querySelectorAll('[data-scope]')) {
  button.onclick = () => {
    scope = button.dataset.scope;
    for (const sibling of button.parentElement.children) sibling.setAttribute('aria-pressed', String(sibling === button));
    $('group-title').textContent = button.textContent;
    list();
  };
}
list();
