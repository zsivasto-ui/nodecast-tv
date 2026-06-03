/**
 * Series Page Controller
 * Handles TV series browsing and playback
 */

class SeriesPage {
    constructor(app) {
        this.app = app;
        this.container = document.getElementById('series-grid');
        this.sourceSelect = document.getElementById('series-source-select');
        this.categorySelect = document.getElementById('series-category-select');
        this.searchInput = document.getElementById('series-search');
        this.detailsPanel = document.getElementById('series-details');
        this.seasonsContainer = document.getElementById('series-seasons');

        this.seriesList = [];
        this.categories = [];
        this.sources = [];
        this.currentBatch = 0;
        this.batchSize = 24;
        this.filteredSeries = [];
        this.isLoading = false;
        this.observer = null;
        this.hiddenCategoryIds = new Set();
        this.currentSeries = null;
        this.favoriteIds = new Set(); // Track favorite series IDs
        this.showFavoritesOnly = false;

        // Client-side cache to avoid hammering slow provider/VM on every page view
        this._cache = new Map();
        this._cacheTTL = 5 * 60 * 1000; // 5 minutes

        this.init();
    }

    init() {
        // Source change handler
        this.sourceSelect?.addEventListener('change', async () => {
            await this.loadCategories();
            await this.loadSeries();
        });

        // Category change handler
        this.categorySelect?.addEventListener('change', () => {
            this.loadSeries();
        });

        // Search with debounce
        let searchTimeout;
        this.searchInput?.addEventListener('input', () => {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => this.filterAndRender(), 300);
        });

        // Back button
        document.querySelector('.series-back-btn')?.addEventListener('click', () => {
            this.hideDetails();
        });

        // Set up IntersectionObserver for lazy loading
        this.observer = new IntersectionObserver((entries) => {
            if (entries[0].isIntersecting && !this.isLoading) {
                this.renderNextBatch();
            }
        }, { rootMargin: '200px' });

        // Favorites filter toggle
        const favBtn = document.getElementById('series-favorites-btn');
        favBtn?.addEventListener('click', () => {
            this.showFavoritesOnly = !this.showFavoritesOnly;
            favBtn.classList.toggle('active', this.showFavoritesOnly);
            this.filterAndRender();
        });
    }

    async show() {
        // Hide details panel when showing page
        this.hideDetails();

        // Load sources if not loaded
        // Load sources if not loaded
        if (this.sources.length === 0) {
            await this.loadSources();
        }

        // Load favorites
        await this.loadFavorites();

        // Load series if empty
        if (this.seriesList.length === 0) {
            await this.loadCategories();
            await this.loadSeries();
        }
    }

    hide() {
        // Page is hidden
    }

    async loadFavorites() {
        try {
            const favs = await API.favorites.getAll(null, 'series');
            this.favoriteIds = new Set(favs.map(f => `${f.source_id}:${f.item_id}`));
        } catch (err) {
            console.error('Error loading favorites:', err);
        }
    }

    // Helper to timeout slow API calls (prevents endless spinners on slow providers/low-resource VM)
    withTimeout(promise, ms = 15000) {
        return Promise.race([
            promise,
            new Promise((_, reject) => setTimeout(() => reject(new Error('Request timed out - provider slow or VM overloaded')), ms))
        ]);
    }

    _getCache(key) {
        const entry = this._cache.get(key);
        if (entry && Date.now() - entry.time < this._cacheTTL) return entry.data;
        return null;
    }
    _setCache(key, data) {
        this._cache.set(key, { data, time: Date.now() });
    }

    // Persistent last-good cache in localStorage so slow loads can still show previous results
    _getLsCache(key) {
        try {
            const raw = localStorage.getItem('nc_series_' + key);
            if (!raw) return null;
            const e = JSON.parse(raw);
            if (Date.now() - e.t < 15 * 60 * 1000) return e.data; // 15min
        } catch (_) {}
        return null;
    }
    _setLsCache(key, data) {
        try { localStorage.setItem('nc_series_' + key, JSON.stringify({ t: Date.now(), data })); } catch (_) {}
    }

    async loadSources() {
        try {
            const allSources = await API.sources.getAll();
            this.sources = allSources.filter(s => s.type === 'xtream' && s.enabled);

            this.sourceSelect.innerHTML = '<option value="">All Sources</option>';
            this.sources.forEach(s => {
                const option = document.createElement('option');
                option.value = s.id;
                option.textContent = s.name;
                this.sourceSelect.appendChild(option);
            });
        } catch (err) {
            console.error('Error loading sources:', err);
        }
    }

    async loadCategories() {
        try {
            this.categories = [];
            this.hiddenCategoryIds = new Set();
            this.categorySelect.innerHTML = '<option value="">All Categories</option>';

            const sourceId = this.sourceSelect.value;
            const sourcesToLoad = sourceId
                ? this.sources.filter(s => s.id === parseInt(sourceId))
                : this.sources;

            // Fetch hidden items for each source (parallel)
            const hiddenPromises = sourcesToLoad.map(async (source) => {
                try {
                    const hiddenItems = await API.channels.getHidden(source.id);
                    hiddenItems.forEach(h => {
                        if (h.item_type === 'series_category') {
                            this.hiddenCategoryIds.add(`${source.id}:${h.item_id}`);
                        }
                    });
                } catch (err) {
                    console.warn(`Failed to load hidden items from source ${source.id}`);
                }
            });
            await Promise.all(hiddenPromises);

            // Load categories in parallel + timeout + cache
            const catPromises = sourcesToLoad.map(async (source) => {
                const cacheKey = `scats_${source.id}`;
                let cats = this._getCache(cacheKey);
                if (!cats) {
                    try {
                        cats = await this.withTimeout(API.proxy.xtream.seriesCategories(source.id), 15000);
                        if (cats && Array.isArray(cats)) this._setCache(cacheKey, cats);
                    } catch (err) {
                        console.warn(`Failed to load series categories from source ${source.id}:`, err.message);
                        cats = [];
                    }
                }
                return (cats || [])
                    .filter(c => !this.hiddenCategoryIds.has(`${source.id}:${c.category_id}`))
                    .map(c => ({ ...c, sourceId: source.id }));
            });
            const catResults = await Promise.all(catPromises);
            catResults.forEach(cats => this.categories.push(...cats));

            // Populate dropdown
            this.categories.forEach(c => {
                const option = document.createElement('option');
                option.value = `${c.sourceId}:${c.category_id}`;
                option.textContent = c.category_name;
                this.categorySelect.appendChild(option);
            });
        } catch (err) {
            console.error('Error loading categories:', err);
        }
    }

    async loadSeries() {
        this.isLoading = true;
        this.container.innerHTML = '<div class="loading"><div class="loading-spinner"></div><div style="margin-top:6px;font-size:12px;opacity:.7;">Loading series from provider(s)...</div></div>';

        try {
            this.seriesList = [];

            const sourceId = this.sourceSelect.value;
            const categoryValue = this.categorySelect.value;

            const sourcesToLoad = sourceId
                ? this.sources.filter(s => s.id === parseInt(sourceId))
                : this.sources;

            // Load series in parallel + timeout + mem + LS cache to prevent endless spinner
            const seriesPromises = sourcesToLoad.map(async (source) => {
                let catId = null;
                if (categoryValue) {
                    const [catSourceId, categoryId] = categoryValue.split(':');
                    if (parseInt(catSourceId) === source.id) {
                        catId = categoryId;
                    } else if (sourceId) {
                        return [];
                    }
                }
                const cacheKey = `series_${source.id}_${catId || 'all'}`;
                let series = this._getCache(cacheKey) || this._getLsCache(cacheKey);
                if (!series) {
                    try {
                        series = await this.withTimeout(API.proxy.xtream.series(source.id, catId), 20000);
                        if (series && Array.isArray(series)) {
                            this._setCache(cacheKey, series);
                            this._setLsCache(cacheKey, series);
                        }
                        console.log(`[Series] Source ${source.id}, Category ${catId || 'ALL'}: Got ${series?.length || 0} series`);
                    } catch (err) {
                        console.warn(`Failed to load series from source ${source.id}:`, err.message);
                        series = this._getLsCache(cacheKey) || [];
                    }
                } else if (!this._getCache(cacheKey) && series) {
                    this._setCache(cacheKey, series);
                }
                return (series || [])
                    .filter(s => !this.hiddenCategoryIds.has(`${source.id}:${s.category_id}`))
                    .map(s => ({
                        ...s,
                        sourceId: source.id,
                        id: `${source.id}:${s.series_id}`
                    }));
            });
            const seriesResults = await Promise.all(seriesPromises);
            seriesResults.forEach(series => this.seriesList.push(...series));

            console.log(`[Series] Total loaded: ${this.seriesList.length} series`);
            this.filterAndRender();
        } catch (err) {
            console.error('Error loading series:', err);
            if (this.seriesList && this.seriesList.length) {
                this.filterAndRender();
            } else {
                this.container.innerHTML = '<div class="empty-state"><p>Error loading series</p><p class="hint">Try refreshing source or check connection</p></div>';
            }
        } finally {
            this.isLoading = false;
        }
    }

    filterAndRender() {
        const searchTerm = this.searchInput?.value?.toLowerCase() || '';

        this.filteredSeries = this.seriesList.filter(s => {
            // Filter by favorites if enabled
            if (this.showFavoritesOnly) {
                const favKey = `${s.sourceId}:${s.series_id}`;
                if (!this.favoriteIds.has(favKey)) return false;
            }
            if (searchTerm && !s.name?.toLowerCase().includes(searchTerm)) {
                return false;
            }
            return true;
        });

        console.log(`[Series] Displaying ${this.filteredSeries.length} of ${this.seriesList.length} series`);

        this.currentBatch = 0;
        this.container.innerHTML = '';

        if (this.filteredSeries.length === 0) {
            this.container.innerHTML = '<div class="empty-state"><p>No series found</p></div>';
            return;
        }

        // Create loader element
        const loader = document.createElement('div');
        loader.className = 'series-loader';
        loader.innerHTML = '<div class="loading-spinner"></div>';
        this.container.appendChild(loader);

        // Render initial batches
        for (let i = 0; i < 5; i++) {
            this.renderNextBatch();
        }

        // Start observing loader
        this.observer.observe(loader);
    }

    renderNextBatch() {
        const start = this.currentBatch * this.batchSize;
        const end = start + this.batchSize;
        const batch = this.filteredSeries.slice(start, end);

        if (batch.length === 0) {
            const loader = this.container.querySelector('.series-loader');
            if (loader) loader.style.display = 'none';
            return;
        }

        const fragment = document.createDocumentFragment();

        batch.forEach(series => {
            const card = document.createElement('div');
            card.className = 'series-card';
            card.dataset.seriesId = series.series_id;
            card.dataset.sourceId = series.sourceId;

            const poster = series.cover || '/img/placeholder.png';
            const year = series.year || series.releaseDate?.substring(0, 4) || '';
            const rating = series.rating ? `${Icons.star} ${series.rating}` : '';

            const isFav = this.favoriteIds.has(`${series.sourceId}:${series.series_id}`);

            card.innerHTML = `
                <div class="series-poster">
                    <img src="${poster}" alt="${series.name}" 
                         onerror="this.onerror=null;this.src='/img/placeholder.png'" loading="lazy">
                    <div class="series-play-overlay">
                        <span class="play-icon">${Icons.play}</span>
                    </div>
                    <button class="favorite-btn ${isFav ? 'active' : ''}" title="${isFav ? 'Remove from Favorites' : 'Add to Favorites'}">
                        <span class="fav-icon">${isFav ? Icons.favorite : Icons.favoriteOutline}</span>
                    </button>
                </div>
                <div class="series-card-info">
                    <div class="series-title">${series.name}</div>
                    <div class="series-meta">
                        ${year ? `<span>${year}</span>` : ''}
                        ${rating ? `<span>${rating}</span>` : ''}
                    </div>
                </div>
            `;

            card.addEventListener('click', (e) => {
                if (e.target.closest('.favorite-btn')) {
                    const btn = e.target.closest('.favorite-btn');
                    this.toggleFavorite(series, btn);
                    e.stopPropagation();
                } else {
                    this.showSeriesDetails(series);
                }
            });
            fragment.appendChild(card);
        });

        // Insert before loader
        const loader = this.container.querySelector('.series-loader');
        if (loader) {
            this.container.insertBefore(fragment, loader);
        } else {
            this.container.appendChild(fragment);
        }

        this.currentBatch++;

        // Hide loader if done
        if (end >= this.filteredSeries.length && loader) {
            loader.style.display = 'none';
        }
    }

    async showSeriesDetails(series) {
        this.currentSeries = series;

        // Show details panel
        this.container.classList.add('hidden');
        this.detailsPanel.classList.remove('hidden');

        // Set header info
        document.getElementById('series-poster').src = series.cover || '/img/placeholder.png';
        document.getElementById('series-title').textContent = series.name;
        document.getElementById('series-plot').textContent = series.plot || '';

        // Show loading
        this.seasonsContainer.innerHTML = '<div class="loading"><div class="loading-spinner"></div></div>';

        try {
            // Fetch series info (seasons/episodes)
            const info = await API.proxy.xtream.seriesInfo(series.sourceId, series.series_id);

            if (!info || !info.episodes) {
                this.seasonsContainer.innerHTML = '<p class="hint">No episodes found</p>';
                return;
            }

            // Store series info for WatchPage
            this.currentSeriesInfo = info;

            // Render seasons and episodes
            let html = '';
            const seasons = Object.keys(info.episodes).sort((a, b) => parseInt(a) - parseInt(b));

            seasons.forEach(seasonNum => {
                const episodes = info.episodes[seasonNum];
                html += `
                <div class="season-group">
                    <div class="season-header">
                        <span class="season-expander">${Icons.chevronDown}</span>
                        <span class="season-name">Season ${seasonNum} (${episodes.length} episodes)</span>
                    </div>
                    <div class="episode-list">
                        ${episodes.map(ep => `
                            <div class="episode-item" data-episode-id="${ep.id}" data-source-id="${series.sourceId}" data-container="${ep.container_extension || 'mp4'}">
                                <span class="episode-number">E${ep.episode_num}</span>
                                <span class="episode-title">${ep.title || `Episode ${ep.episode_num}`}</span>
                                <span class="episode-duration">${ep.duration || ''}</span>
                            </div>
                        `).join('')}
                    </div>
                </div>`;
            });

            this.seasonsContainer.innerHTML = html;

            // Add click handlers
            this.seasonsContainer.querySelectorAll('.season-header').forEach(header => {
                header.addEventListener('click', () => {
                    header.closest('.season-group').classList.toggle('collapsed');
                });
            });

            this.seasonsContainer.querySelectorAll('.episode-item').forEach(ep => {
                ep.addEventListener('click', () => this.playEpisode(ep));
            });

        } catch (err) {
            console.error('Error loading series info:', err);
            this.seasonsContainer.innerHTML = '<p class="hint" style="color: var(--color-error);">Error loading episodes</p>';
        }
    }

    hideDetails() {
        this.detailsPanel.classList.add('hidden');
        this.container.classList.remove('hidden');
        this.currentSeries = null;
    }

    async playEpisode(episodeEl) {
        const episodeId = episodeEl.dataset.episodeId;
        const sourceId = parseInt(episodeEl.dataset.sourceId);
        const container = episodeEl.dataset.container || 'mp4';

        // Get season and episode number from the episode element context
        const seasonGroup = episodeEl.closest('.season-group');
        const seasonHeader = seasonGroup?.querySelector('.season-name')?.textContent || '';
        const seasonMatch = seasonHeader.match(/Season (\d+)/);
        const seasonNum = seasonMatch ? seasonMatch[1] : '1';
        const episodeNum = episodeEl.querySelector('.episode-number')?.textContent?.replace('E', '') || '1';

        try {
            // Get stream URL for episode (use 'series' type)
            const result = await API.proxy.xtream.getStreamUrl(sourceId, episodeId, 'series', container);

            if (result && result.url) {
                // Play in dedicated Watch page
                if (this.app.pages.watch) {
                    const episodeTitle = episodeEl.querySelector('.episode-title')?.textContent || `Episode ${episodeNum}`;

                    this.app.pages.watch.play({
                        type: 'series',
                        id: episodeId,
                        title: this.currentSeries?.name || 'Series',
                        subtitle: `S${seasonNum} E${episodeNum} - ${episodeTitle}`,
                        poster: this.currentSeries?.cover,
                        description: this.currentSeries?.plot || '',
                        year: this.currentSeries?.year,
                        rating: this.currentSeries?.rating,
                        sourceId: sourceId,
                        seriesId: this.currentSeries?.series_id,
                        seriesInfo: this.currentSeriesInfo,
                        currentSeason: seasonNum,
                        currentEpisode: episodeNum,
                        containerExtension: container
                    }, result.url);
                }
            }
        } catch (err) {
            console.error('Error playing episode:', err);
        }
    }

    async toggleFavorite(series, btn) {
        const favKey = `${series.sourceId}:${series.series_id}`;
        const isFav = this.favoriteIds.has(favKey);
        const iconSpan = btn.querySelector('.fav-icon');

        try {
            // Optimistic update
            if (isFav) {
                this.favoriteIds.delete(favKey);
                btn.classList.remove('active');
                btn.title = 'Add to Favorites';
                if (iconSpan) iconSpan.innerHTML = Icons.favoriteOutline;
                await API.favorites.remove(series.sourceId, series.series_id, 'series');
            } else {
                this.favoriteIds.add(favKey);
                btn.classList.add('active');
                btn.title = 'Remove from Favorites';
                if (iconSpan) iconSpan.innerHTML = Icons.favorite;
                await API.favorites.add(series.sourceId, series.series_id, 'series');
            }
        } catch (err) {
            console.error('Error toggling favorite:', err);
            // Revert on error
            if (isFav) {
                this.favoriteIds.add(favKey);
                btn.classList.add('active');
                if (iconSpan) iconSpan.innerHTML = Icons.favorite;
            } else {
                this.favoriteIds.delete(favKey);
                btn.classList.remove('active');
                if (iconSpan) iconSpan.innerHTML = Icons.favoriteOutline;
            }
        }
    }
}

window.SeriesPage = SeriesPage;
