(() => {
  const form = document.querySelector('#finder-form');
  if (!form) return;
  const query = document.querySelector('#finder-query');
  const list = document.querySelector('#finder-results');
  const status = document.querySelector('#finder-status');
  const submit = document.querySelector('#finder-submit');
  const model = document.querySelector('meta[name="finder-model"]')?.content;
  const modelUrl = window.crossOriginIsolated && model ? new URL(model, document.baseURI).href : null;
  const rows = [...list.children];
  const terms = text => text.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '').match(/[\p{L}\p{N}]+/gu) ?? [];
  const entries = rows.map(row => {
    const [category, content] = row.querySelector('a').children;
    const description = [...content.childNodes, category]
      .filter(node => node.nodeType !== Node.COMMENT_NODE)
      .map(node => node.textContent.trim())
      .filter(Boolean).join('. ');
    return {row, words: terms(description), description};
  });

  const render = matches => {
    const visible = new Set(matches);
    for (const row of rows) row.hidden = !visible.has(row);
    for (const row of matches) list.appendChild(row);
  };

  function keywordSearch() {
    const wanted = [...new Set(terms(query.value))];
    list.hidden = query.value.trim() === '';
    if (list.hidden) {
      status.textContent = '';
      return;
    }

    const matches = entries.map(entry => ({
      ...entry,
      score: wanted.filter(term => entry.words.some(word => word.startsWith(term))).length,
    })).filter(entry => entry.score > 0).sort((a, b) => b.score - a.score);

    render(matches.map(entry => entry.row));
    status.textContent = matches.length === 0 ? 'No keyword matches.'
      : `${matches.length} keyword ${matches.length === 1 ? 'match' : 'matches'}`;
  }

  form.addEventListener('submit', event => {
    event.preventDefault();
    if (submit.disabled) return;
    if (modelUrl) searchByMeaning();
    else keywordSearch();
  });
  query.addEventListener('input', keywordSearch);
  form.hidden = false;
  keywordSearch();

  if (!modelUrl) return;

  const modelStatus = document.querySelector('#finder-model-status');
  const modelLabel = modelStatus.textContent;
  document.querySelector('#finder-local-details').hidden = false;

  let bridge;
  let runtime;
  let preparation;
  let rankResources;
  let started = false;
  let scheduled = false;

  function loadBridge() {
    bridge ??= import(new URL('finder-bridge.js', document.baseURI).href)
      .then(module => module.loadFinderBridge())
      .catch(error => {
        bridge = undefined;
        throw error;
      });
    return bridge;
  }

  function loadRuntime() {
    runtime ??= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = new URL('semantic.dart.js', document.baseURI).href;
      script.onload = () => {
        if (typeof window.finderPrepare === 'function') resolve();
        else reject(new Error('Local search did not start.'));
      };
      script.onerror = () => reject(new Error('Could not load local search.'));
      document.head.appendChild(script);
    }).catch(error => {
      runtime = undefined;
      throw error;
    });
    return runtime;
  }

  function prepareSearch() {
    if (preparation) return preparation;
    started = true;
    modelStatus.textContent = 'Preparing local search · 37 MB model';
    preparation = Promise.all([loadBridge(), loadRuntime()])
      .then(() => window.finderPrepare(entries.map(entry => entry.description), modelUrl))
      .then(rank => {
        rankResources = rank;
        modelStatus.textContent = 'Local search ready';
        return rank;
      })
      .catch(error => {
        preparation = undefined;
        modelStatus.textContent = modelLabel;
        throw error;
      });
    return preparation;
  }

  function canWarmUp() {
    return document.readyState === 'complete' && !document.hidden &&
      window.caches && !navigator.connection?.saveData && !started;
  }

  function scheduleWarmUp() {
    if (scheduled || !canWarmUp()) return;
    scheduled = true;
    const start = () => {
      scheduled = false;
      if (canWarmUp()) prepareSearch().catch(() => {});
    };
    if (window.requestIdleCallback) window.requestIdleCallback(start);
    else window.setTimeout(start, 250);
  }

  window.addEventListener('load', scheduleWarmUp, {once: true});
  document.addEventListener('visibilitychange', scheduleWarmUp);
  scheduleWarmUp();

  async function searchByMeaning() {
    const question = query.value.trim();
    if (!question) {
      query.focus();
      return;
    }
    const isCurrentQuery = () => query.value.trim() === question;
    submit.disabled = true;
    if (!rankResources) status.textContent = 'Preparing local search…';
    try {
      const rank = rankResources ?? await prepareSearch();
      if (!isCurrentQuery()) return;
      const matches = await rank(question);
      if (!isCurrentQuery()) return;
      render(matches.map(index => rows[index]));
      status.textContent = 'Closest links · matched in your browser';
    } catch (error) {
      console.error(error);
      if (!isCurrentQuery()) return;
      keywordSearch();
      status.textContent = 'Local matching is unavailable. Keyword results are still available.';
    } finally {
      submit.disabled = false;
    }
  }
})();
