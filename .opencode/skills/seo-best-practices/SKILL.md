---
name: seo-best-practices
description: This skill should be used when the user asks to "optimize a website for SEO", "improve search engine rankings", "apply SEO best practices", "do on-page SEO", or needs guidance on technical SEO, keyword research, content optimization, or link building strategies.
---

# SEO Best Practices

A comprehensive guide to improving search engine visibility through proven on-page, technical, and off-page SEO techniques. Covers keyword research, content optimization, technical foundations, and link building — aligned with Google's guidelines and current ranking signals.

## Core SEO Pillars

SEO has three interconnected pillars:

- **On-page SEO** — Content, HTML elements, and page structure under direct control
- **Technical SEO** — Crawlability, indexability, speed, and site health
- **Off-page SEO** — Backlinks, brand mentions, and external authority signals

A strong strategy addresses all three. Start with technical foundations, then on-page optimization, then off-page authority building.

---

## Keyword Research

Keyword research is the foundation. Target keywords with genuine search volume that match the site's authority level.

### Process

1. Brainstorm seed topics related to the business
2. Use a keyword tool (Ahrefs, Semrush, Moz) to expand into specific terms
3. Evaluate each keyword for: search volume, keyword difficulty, and search intent
4. Prioritize keywords where the site's domain authority is competitive
5. Mix short-tail (high volume, competitive) and long-tail (lower volume, easier to rank)

### Search Intent Alignment

Match content type to what searchers actually want. Inspect the top 5–10 results for any target keyword before creating content:

| Intent Type | What Searchers Want | Content Format |
|---|---|---|
| Informational | Learn something | Blog post, guide, how-to |
| Commercial | Compare options | Listicle, comparison, review |
| Transactional | Buy or sign up | Product/service page, landing page |
| Navigational | Find a specific site | Homepage, brand page |

Creating a product page for an informational keyword — or a blog post for a transactional keyword — will not rank regardless of optimization quality.

### What to Avoid

- Targeting keywords with zero search volume
- Keyword cannibalization: multiple pages targeting the same keyword
- Keyword stuffing: forcing keywords unnaturally into content

---

## On-Page SEO

### Title Tags

The title tag is the single most important on-page HTML element.

- Include the primary keyword, ideally near the start
- Keep under 60 characters to avoid truncation in SERPs
- Make each title unique across the site
- Write for humans first — the title must be compelling enough to earn the click
- Format: `Primary Keyword – Secondary Keyword | Brand Name`

### Meta Descriptions

Meta descriptions do not directly affect rankings but significantly influence click-through rate.

- Write a compelling summary that matches search intent
- Keep between 150–160 characters
- Include the target keyword (Google bolds it in results)
- Make each description unique
- Avoid non-alpha characters (quotes, ampersands) — Google strips them

### Headings (H1–H6)

- Use exactly one H1 per page; it should contain the primary keyword
- Use H2s for major sections, H3s for subsections — follow a logical hierarchy
- Include keyword variations and semantic phrases in subheadings
- Headings help both users scanning content and crawlers understanding page structure

### URL Structure

- Use short, descriptive slugs containing the target keyword
- Separate words with hyphens, not underscores
- Avoid stop words, numbers, and special characters where possible
- Keep URLs lowercase
- Example: `/seo-best-practices` not `/page?id=1234&cat=seo`

### Content Quality

Content is the primary ranking factor. Google's helpful content guidelines require:

- **Originality** — Do not duplicate content from other pages or sites
- **Depth** — Cover the topic comprehensively; analyze what subtopics top-ranking pages include
- **Accuracy** — Cite reputable sources; keep content updated
- **People-first** — Write for the reader, not for search engines
- **E-E-A-T signals** — Demonstrate Experience, Expertise, Authoritativeness, and Trustworthiness

Place the primary keyword in the first paragraph. Use it naturally 2–4 times throughout the content depending on length. Include semantic keyphrases (related terms and synonyms) to signal topical relevance.

### Image Optimization

- Use descriptive filenames with hyphens: `seo-checklist-2025.png` not `img001.png`
- Write descriptive alt text for every image — describe what the image shows
- Compress images to reduce file size (TinyPNG, ShortPixel, WebP format)
- Enable lazy loading for images below the fold
- Add ImageObject schema for important visuals (infographics, product images)

### Internal Linking

Internal links distribute PageRank across the site and help crawlers discover pages.

- Link from high-authority pages to pages that need ranking boosts
- Use descriptive, keyword-rich anchor text — not "click here"
- Link to relevant content that adds value for the reader
- Fix broken internal links regularly
- When publishing new content, add internal links from existing relevant pages

### Schema Markup

Structured data helps search engines understand page content and can unlock rich results (star ratings, FAQs, breadcrumbs, etc.).

Common schema types:
- `Article` — Blog posts and news articles
- `FAQPage` — Pages with question-and-answer sections
- `HowTo` — Step-by-step instructional content
- `Product` — Ecommerce product pages
- `LocalBusiness` — Business location and contact info
- `BreadcrumbList` — Site navigation hierarchy

Validate schema with Google's Rich Results Test before deploying.

---

## Technical SEO

### Crawlability and Indexability

- Submit an XML sitemap to Google Search Console
- Configure `robots.txt` to block only pages that should not be indexed
- Use `rel="canonical"` to consolidate duplicate content to a single preferred URL
- Implement 301 redirects for moved or deleted pages
- Fix crawl errors reported in Google Search Console

### Page Speed and Core Web Vitals

Google uses Core Web Vitals as ranking signals. Target these thresholds:

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| LCP (Largest Contentful Paint) | < 2.5s | 2.5–4s | > 4s |
| INP (Interaction to Next Paint) | < 200ms | 200–500ms | > 500ms |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1–0.25 | > 0.25 |

Speed improvement tactics:
- Compress and resize images; use WebP format
- Use a CDN to serve assets from servers close to users
- Enable browser caching
- Minimize render-blocking JavaScript and CSS
- Use lazy loading for offscreen images
- Choose a lightweight, well-optimized theme or framework

Audit with Google PageSpeed Insights and Google Search Console's Core Web Vitals report.

### Mobile-First Indexing

Google indexes the mobile version of pages first. Ensure:
- Responsive design that adapts to all screen sizes
- Text is readable without zooming
- Tap targets (buttons, links) are adequately sized
- No content hidden on mobile that is visible on desktop

### HTTPS

HTTPS is a confirmed ranking signal since 2014. Every page must be served over HTTPS. Install an SSL certificate (free via Let's Encrypt if the host does not provide one). After migration, update all internal links and canonical tags to HTTPS.

### Duplicate Content

Duplicate content wastes crawl budget and dilutes ranking signals. Resolve it by:
- Setting canonical URLs on all pages
- Redirecting non-preferred URL variants (www vs. non-www, trailing slash vs. none)
- Consolidating thin or near-duplicate pages

---

## Off-Page SEO

### Backlinks

Backlinks remain one of the strongest ranking signals. Quality matters more than quantity — one link from an authoritative, relevant site outweighs dozens from low-quality sources.

Effective link building tactics:
- **Link bait** — Create data studies, original research, or definitive guides that others naturally cite
- **Skyscraper technique** — Identify widely-linked content, create a superior version, reach out to linkers
- **Broken link building** — Find broken links on relevant sites, offer replacement content
- **Guest posting** — Contribute expert content to authoritative sites in the niche
- **Brand mention reclamation** — Find unlinked brand mentions and request a link be added

Avoid: buying links, reciprocal link schemes, and low-quality directory submissions. These violate Google's spam policies and can result in manual penalties.

### E-E-A-T Signals

Google's Quality Rater Guidelines assess Experience, Expertise, Authoritativeness, and Trustworthiness. Strengthen these signals:

- Add detailed author bios with credentials and links to published work
- Include original research, case studies, or firsthand experience
- Display reviews, testimonials, and third-party recognition
- Keep About page, contact information, and editorial policies accurate and accessible
- Secure the site with HTTPS
- Cite reputable sources throughout content

### Brand Authority

Google and AI tools increasingly favor recognized brands. Build brand signals by:
- Maintaining consistent brand name, description, and information across all directories and profiles
- Keeping Google Business Profile complete and current
- Creating dedicated pages for each core product or service
- Earning mentions and citations from authoritative sources in the niche

---

## Topical Authority

Topical authority — deep coverage of a subject area — signals expertise to search engines and AI tools.

### Content Cluster Strategy

1. Identify a core topic relevant to the business
2. Create a **pillar page** with a broad overview of the topic
3. Create **cluster pages** covering specific subtopics in depth
4. Link the pillar page to all cluster pages, and each cluster page back to the pillar
5. Use consistent URL structure to reflect the hierarchy: `/topic/subtopic`
6. Update content regularly with new data and examples

### Content Gap Analysis

Identify subtopics competitors cover that the site does not:
1. Identify the top 3–5 ranking pages for the target keyword
2. Analyze their headings and content structure
3. Note subtopics that appear across multiple top-ranking pages
4. Add missing subtopics to existing content or create new cluster pages

---

## Monitoring and Measurement

### Google Search Console (Free)

Essential reports to check regularly:
- **Performance** — Impressions, clicks, CTR, and average position by keyword and page
- **Coverage** — Indexed pages, crawl errors, and excluded URLs
- **Core Web Vitals** — Field data on LCP, INP, and CLS
- **Mobile Usability** — Mobile-specific rendering issues

### Google Analytics (Free)

Track organic traffic trends, bounce rate by landing page, and conversion rates from organic search.

### Ongoing Maintenance

- Audit the site for technical issues quarterly
- Update high-traffic pages with fresh data and examples annually
- Monitor keyword rankings and adjust content strategy based on movement
- Check for and fix broken links regularly

---

## Quick Reference Checklist

**On-Page**
- [ ] Primary keyword in title tag, H1, first paragraph, and URL
- [ ] Title tag under 60 characters; unique per page
- [ ] Meta description 150–160 characters; compelling and unique
- [ ] Logical heading hierarchy (one H1, H2s for sections)
- [ ] Descriptive alt text on all images
- [ ] Compressed images with descriptive filenames
- [ ] Internal links from relevant existing pages
- [ ] Schema markup validated with Rich Results Test

**Technical**
- [ ] HTTPS enabled site-wide
- [ ] XML sitemap submitted to Google Search Console
- [ ] robots.txt reviewed; no critical pages blocked
- [ ] Canonical tags set on all pages
- [ ] Core Web Vitals passing (LCP < 2.5s, INP < 200ms, CLS < 0.1)
- [ ] Mobile-responsive design
- [ ] No crawl errors in Google Search Console

**Off-Page**
- [ ] Backlink profile reviewed; toxic links disavowed
- [ ] Author bios with credentials on all content
- [ ] Brand information consistent across directories
- [ ] Link building strategy in place

---

## Additional Resources

For detailed guidance on specific areas:
- **`references/keyword-research.md`** — Keyword research process, tools, and intent analysis
- **`references/technical-seo.md`** — Core Web Vitals, crawl configuration, and site architecture
- **`references/content-optimization.md`** — E-E-A-T, topical authority, and content gap analysis
- **`references/link-building.md`** — Backlink tactics, outreach templates, and avoiding penalties
