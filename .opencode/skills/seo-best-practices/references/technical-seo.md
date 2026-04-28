# Technical SEO: Deep Dive

## Table of Contents
1. [Crawling and Indexing](#crawling-indexing)
2. [Site Architecture](#architecture)
3. [Core Web Vitals](#core-web-vitals)
4. [Mobile SEO](#mobile)
5. [HTTPS and Security](#https)
6. [Structured Data](#structured-data)
7. [Technical Audit Checklist](#audit-checklist)

---

## Crawling and Indexing

### How Google Crawls

Googlebot discovers pages through links. It follows links from known pages to find new ones. Pages with no inbound links (orphan pages) may never be crawled.

### robots.txt

The `robots.txt` file at the root of the domain instructs crawlers which paths to avoid. It does not prevent indexing — it only prevents crawling. To block indexing, use `noindex` meta tags.

Common configuration:
```
User-agent: *
Disallow: /admin/
Disallow: /staging/
Allow: /
Sitemap: https://example.com/sitemap.xml
```

Never accidentally block CSS or JavaScript files — Googlebot needs them to render pages correctly.

### XML Sitemaps

Sitemaps list all URLs the site owner wants indexed. Submit via Google Search Console under Sitemaps.

Best practices:
- Include only canonical, indexable URLs
- Exclude paginated pages, filtered URLs, and duplicate content
- Keep sitemaps under 50,000 URLs and 50MB; use sitemap index files for larger sites
- Update sitemaps automatically via CMS plugins (Yoast, RankMath for WordPress)

### Canonical Tags

The `rel="canonical"` tag tells Google which URL is the preferred version when duplicate or near-duplicate content exists at multiple URLs.

```html
<link rel="canonical" href="https://example.com/preferred-page/" />
```

Common use cases:
- HTTP vs. HTTPS versions
- www vs. non-www
- Trailing slash vs. no trailing slash
- URL parameters (e.g., `?sort=price` vs. the base URL)
- Syndicated content pointing back to the original

### Redirects

Use 301 (permanent) redirects when moving or deleting pages. 302 (temporary) redirects do not pass full link equity.

Redirect chains (A → B → C) slow crawling and dilute link equity. Flatten chains so all redirects point directly to the final destination.

---

## Site Architecture

A flat, logical site architecture helps crawlers reach all pages efficiently and distributes PageRank effectively.

### Ideal Structure
```
Homepage (highest authority)
├── Category Page
│   ├── Subcategory Page
│   │   └── Product/Article Page
│   └── Product/Article Page
└── Category Page
    └── Product/Article Page
```

Keep important pages within 3 clicks of the homepage. Pages buried deeper receive less crawl budget and link equity.

### URL Structure

- Use descriptive, keyword-rich slugs
- Reflect site hierarchy in URL paths: `/category/subcategory/page`
- Use hyphens as word separators
- Keep URLs lowercase
- Avoid dynamic parameters in URLs where possible

### Pagination

For paginated content (blog archives, product listings):
- Use `rel="next"` and `rel="prev"` link elements (deprecated by Google but still used by other engines)
- Consider infinite scroll with proper URL updates for each loaded section
- Ensure paginated pages are crawlable and not blocked by robots.txt

---

## Core Web Vitals

Core Web Vitals are Google's user experience metrics used as ranking signals. Measured using real-user data (Chrome User Experience Report) and lab data (PageSpeed Insights).

### Largest Contentful Paint (LCP)

Measures how long it takes for the largest visible content element (image, video, or text block) to load.

**Target: under 2.5 seconds**

Improvement tactics:
- Optimize and compress the hero image or largest above-the-fold element
- Use a CDN to reduce server response time
- Preload critical resources: `<link rel="preload" as="image" href="hero.webp">`
- Remove render-blocking resources (unused CSS/JS)
- Use server-side rendering or static generation for fast initial HTML delivery

### Interaction to Next Paint (INP)

Measures the latency of all user interactions (clicks, taps, keyboard inputs) throughout the page lifecycle.

**Target: under 200 milliseconds**

Improvement tactics:
- Minimize long JavaScript tasks (tasks > 50ms block the main thread)
- Break up long tasks with `setTimeout` or `scheduler.yield()`
- Defer non-critical JavaScript
- Avoid heavy third-party scripts (chat widgets, analytics, ad scripts)

### Cumulative Layout Shift (CLS)

Measures unexpected visual shifts of page elements as the page loads.

**Target: under 0.1**

Improvement tactics:
- Always specify `width` and `height` attributes on images and videos
- Reserve space for ads and embeds with CSS `aspect-ratio` or fixed dimensions
- Avoid inserting content above existing content after load
- Use `font-display: swap` carefully — web font swaps can cause layout shifts

### Measuring Core Web Vitals

- **Google Search Console** → Core Web Vitals report (field data, real users)
- **PageSpeed Insights** — Both field data and lab data for individual URLs
- **Chrome DevTools** → Performance panel (lab data)
- **Ahrefs Site Audit** → Performance report

---

## Mobile SEO

Google uses mobile-first indexing: the mobile version of a page is what Google crawls and indexes.

### Responsive Design

Use CSS media queries to adapt layout to screen size. Avoid separate mobile subdomains (m.example.com) unless the team can maintain content parity between versions.

### Mobile Usability Requirements

- Text readable without zooming (minimum 16px base font)
- Tap targets at least 48×48 CSS pixels with adequate spacing
- No horizontal scrolling
- No content wider than the viewport
- No intrusive interstitials that cover main content on mobile

### Testing

- Google Search Console → Mobile Usability report
- Google's Mobile-Friendly Test tool
- Chrome DevTools → Device emulation

---

## HTTPS and Security

HTTPS encrypts data between the browser and server. It is a confirmed ranking signal and required for many browser features (service workers, geolocation, camera access).

### Migration Checklist

1. Obtain an SSL certificate (free via Let's Encrypt, or through the hosting provider)
2. Install and configure the certificate
3. Update all internal links from `http://` to `https://`
4. Update canonical tags to HTTPS
5. Update the XML sitemap to use HTTPS URLs
6. Set up 301 redirects from all HTTP URLs to HTTPS equivalents
7. Update Google Search Console and Google Analytics properties to HTTPS
8. Check for mixed content warnings (HTTPS pages loading HTTP resources)

---

## Structured Data

Structured data (schema markup) uses JSON-LD, Microdata, or RDFa to annotate page content so search engines can understand it precisely.

### Recommended Format: JSON-LD

Google recommends JSON-LD. Place the script block in the `<head>` or `<body>`.

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "SEO Best Practices Guide",
  "author": {
    "@type": "Person",
    "name": "Author Name"
  },
  "datePublished": "2025-01-01"
}
</script>
```

### High-Value Schema Types

| Schema Type | Use Case | Rich Result |
|---|---|---|
| Article | Blog posts, news | Byline, date in results |
| FAQPage | FAQ sections | Expandable Q&A in SERP |
| HowTo | Step-by-step guides | Steps shown in SERP |
| Product | Ecommerce products | Price, availability, ratings |
| LocalBusiness | Physical locations | Knowledge panel, maps |
| BreadcrumbList | Navigation hierarchy | Breadcrumbs in URL display |
| Review / AggregateRating | Reviews | Star ratings in SERP |

### Validation

Always validate before deploying:
- Google Rich Results Test: `search.google.com/test/rich-results`
- Schema.org Validator: `validator.schema.org`

---

## Technical Audit Checklist

Run a full technical audit quarterly using Semrush Site Audit, Ahrefs Site Audit, or Screaming Frog.

**Crawlability**
- [ ] robots.txt does not block critical pages or resources
- [ ] XML sitemap submitted and error-free in Search Console
- [ ] No orphan pages (pages with no inbound internal links)
- [ ] Redirect chains resolved (all redirects point directly to final destination)
- [ ] No broken internal links (404 errors)

**Indexability**
- [ ] No critical pages accidentally noindexed
- [ ] Canonical tags set correctly on all pages
- [ ] Duplicate content consolidated via canonicals or redirects
- [ ] Paginated pages handled correctly

**Performance**
- [ ] LCP under 2.5 seconds (field data in Search Console)
- [ ] INP under 200 milliseconds
- [ ] CLS under 0.1
- [ ] Images compressed and in modern formats (WebP)
- [ ] CDN in use for static assets

**Mobile**
- [ ] Mobile Usability report shows no errors in Search Console
- [ ] No intrusive interstitials on mobile
- [ ] Tap targets adequately sized

**Security**
- [ ] HTTPS on all pages; no mixed content warnings
- [ ] HTTP redirects to HTTPS
- [ ] No malware or security warnings in Search Console
