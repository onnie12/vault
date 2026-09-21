// Renders one document into <main id="content">. The app calls
// vaultRender({ mode, language, text }) once the page has loaded:
//   mode "markdown": Markdown with GitHub tables, code highlighting and KaTeX math
//   mode "code":     a source file, highlighted as `language` (the file extension)
//   mode "text":     plain text, line breaks kept
"use strict";

function escapeHTML(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderTeX(tex, displayMode) {
  // throwOnError false: a typo in a formula shows the source in red instead of breaking the page.
  return katex.renderToString(tex, { displayMode, throwOnError: false, output: "htmlAndMathml" });
}

function highlight(code, language) {
  if (language && hljs.getLanguage(language)) {
    return hljs.highlight(code, { language, ignoreIllegals: true }).value;
  }
  return escapeHTML(code);
}

// $$...$$ or \[...\] on their own lines.
const mathBlock = {
  name: "mathBlock",
  level: "block",
  start(src) {
    const match = src.match(/(?:^|\n)[ \t]*(\$\$|\\\[)/);
    return match ? match.index + match[0].length - match[1].length : undefined;
  },
  tokenizer(src) {
    const match = /^[ \t]*(?:\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\])[ \t]*(?:\n|$)/.exec(src);
    if (match) {
      return { type: "mathBlock", raw: match[0], text: (match[1] ?? match[2]).trim() };
    }
  },
  renderer(token) {
    return `<div class="math-block">${renderTeX(token.text, true)}</div>\n`;
  },
};

// $...$, \(...\) and $$...$$ inside a line. "$5 and $10" stays text: the opening $
// must be followed by a non-space, the closing $ preceded by a non-space and not
// followed by a digit (the same rule Pandoc uses).
const mathInline = {
  name: "mathInline",
  level: "inline",
  start(src) {
    const match = src.match(/\$|\\\(/);
    return match ? match.index : undefined;
  },
  tokenizer(src) {
    let match = /^\$\$(?!\s)([^$]+?)\$\$/.exec(src);
    if (match) return { type: "mathInline", raw: match[0], text: match[1], display: true };
    match = /^\\\(([\s\S]+?)\\\)/.exec(src);
    if (match) return { type: "mathInline", raw: match[0], text: match[1], display: false };
    match = /^\$(?![\s$])((?:\\\$|[^$\n])+?)(?<![\s\\])\$(?!\d)/.exec(src);
    if (match) return { type: "mathInline", raw: match[0], text: match[1], display: false };
  },
  renderer(token) {
    return renderTeX(token.text, token.display);
  },
};

marked.use({
  gfm: true,
  // A single line break stays a line break, the way Claude shows its answers.
  // (Standard Markdown would join "**Interviewer:** ...\n**Length:** ..." into one line.)
  breaks: true,
  extensions: [mathBlock, mathInline],
  renderer: {
    code({ text, lang }) {
      const language = (lang || "").trim().split(/\s+/)[0].toLowerCase();
      if (language === "math" || language === "latex" || language === "tex") {
        return `<div class="math-block">${renderTeX(text, true)}</div>\n`;
      }
      const cssClass = language ? ` language-${escapeHTML(language)}` : "";
      return `<pre><code class="hljs${cssClass}">${highlight(text, language)}</code></pre>\n`;
    },
  },
});

function wrapTables(root) {
  for (const table of root.querySelectorAll("table")) {
    const wrapper = document.createElement("div");
    wrapper.className = "table-scroll";
    table.replaceWith(wrapper);
    wrapper.appendChild(table);
  }
}

window.vaultRender = function (payload) {
  const content = document.getElementById("content");
  const text = payload.text || "";

  if (payload.mode === "markdown") {
    content.innerHTML = marked.parse(text);
    wrapTables(content);
  } else if (payload.mode === "code") {
    content.innerHTML =
      `<pre class="code-file"><code class="hljs">${highlight(text, (payload.language || "").toLowerCase())}</code></pre>`;
  } else {
    content.innerHTML = `<pre class="plain-text">${escapeHTML(text)}</pre>`;
  }
  return content.childElementCount;
};
