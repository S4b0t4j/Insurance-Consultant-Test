// Report Studio helper: extract the text layer of a PDF with the locally
// bundled pdf.js. Called from Dart via js_interop (extractPdfText).
(function () {
  if (typeof pdfjsLib === 'undefined') return;
  pdfjsLib.GlobalWorkerOptions.workerSrc = 'pdfjs/pdf.worker.min.js';

  window.extractPdfText = async function (bytes) {
    const pdf = await pdfjsLib.getDocument({ data: bytes }).promise;
    const pages = [];
    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const tc = await page.getTextContent();
      pages.push(tc.items.map((it) => it.str).join(' '));
    }
    return pages.join('\n\n');
  };
})();
