import {
  Source,
  Status,
  Chapter,
  Novel,
  Filter,
  Language,
} from 'shosetsu';

const BASE_URL = 'https://fictionzone.net';

export default class FictionZone extends Source {
  // The language of the source.
  language = Language.ENGLISH;

  /**
   * Parses the novel details from the novel page.
   * @param {string} url - The URL of the novel.
   * @returns {Promise<Novel>}
   */
  async getNovel(url) {
    const doc = await this.fetch(url).html();
    const novel = new Novel(url);

    novel.title = doc.select('div.main-content h1.story-title').text();
    novel.author = doc.select('div.author-details h4.author-name a').text();
    novel.cover = doc.select('div.story-sidebar-left-img img').attr('src');

    const summary = doc.select('div.story-main-content div.summary').html();
    novel.description = summary.replace(/<br>/g, '\n').trim();

    const statusText = doc.select('span.story-status').text().toLowerCase();
    novel.status = statusText === 'completed' ? Status.COMPLETED : Status.ONGOING;

    novel.genres = doc.select('div.story-tags a.story-tag').map(el => el.text());

    const chapters = [];
    doc.select('ul.list-chapters li.chapter-item').forEach(el => {
      const chapterUrl = el.select('a').attr('href');
      const name = el.select('a span.chapter-text').text().trim();
      const releaseDate = el.select('a span.chapter-update').text().trim();
      chapters.push(new Chapter(chapterUrl, { name, releaseDate }));
    });

    novel.chapters = chapters;
    return novel;
  }

  /**
   * Parses the chapter content from the chapter page.
   * @param {Chapter} chapter - The chapter to parse.
   * @returns {Promise<string>}
   */
  async getChapter(chapter) {
    const doc = await this.fetch(chapter.url).html();
    const content = doc.select('#chapter-content');
    content.select('div, p').append('\n\n'); // Add newlines between paragraphs
    return content.html();
  }

  /**
   * Searches for novels on the source.
   * @param {string} query - The search query.
   * @param {Filter.Result} filters - The applied filters.
   * @param {number} page - The page number.
   * @returns {Promise<{novels: Novel[], hasNextPage: boolean}>}
   */
  async search(query, filters, page) {
    const url = `${BASE_URL}/search?keyword=${encodeURIComponent(query)}&page=${page}`;
    return this.parseNovelListPage(url);
  }

  /**
   * Browses novels on the source.
   * @param {Filter.Result} filters - The applied filters.
   * @param {number} page - The page number.
   * @returns {Promise<{novels: Novel[], hasNextPage: boolean}>}
   */
  async browse(filters, page) {
    const sort = filters.sort || '/stories/all/latest/1';
    // The filter value already contains the page number, so we need to replace it.
    const url = `${BASE_URL}${sort.replace(/\/\d+$/, `/${page}`)}`;
    return this.parseNovelListPage(url);
  }

  /**
   * A helper function to parse a list of novels from a page.
   * @param {string} url - The URL of the page to parse.
   * @returns {Promise<{novels: Novel[], hasNextPage: boolean}>}
   */
  async parseNovelListPage(url) {
    const doc = await this.fetch(url).html();
    const novels = [];

    doc.select('div.story-item').forEach(el => {
      const novelUrl = el.select('h3.story-title a').attr('href');
      const title = el.select('h3.story-title a').text();
      const cover = el.select('div.story-cover img').attr('src');
      novels.push(new Novel(novelUrl, { title, cover }));
    });

    const hasNextPage = doc.select('li.page-item.active + li.page-item').length > 0;

    return { novels, hasNextPage };
  }
}
