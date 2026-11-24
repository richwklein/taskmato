## Problem / opportunity

The site does not currently provide a clear structure for multi-part topics that span more than one article.

When several articles belong together as part of a series, readers should be able to recognize that relationship and easily move among the related posts.

## Goal

Add article series support so multi-part topics have a clearer structure and readers can navigate all articles that belong to the same series.

The first pass should focus on article-page support rather than introducing dedicated series pages.

## Proposed solution

Add series support through article frontmatter, using fields such as a series name and series order.

Use that metadata to surface series context on article pages so each article in a series can link to the other articles in that same series.

Implementation may also require supporting utilities to:
- identify related articles in the same series
- sort them in a stable order
- render a consistent series section on article pages

A future pass could explore whether series information should also appear in feeds, structured data, or other metadata, but the initial implementation should focus on article pages only.

Use the referenced 11ty article as implementation inspiration where helpful.

## In scope

- add frontmatter support for article series information
- support at least a series name and series order
- add any supporting utilities needed to group and sort series entries
- render series context on article pages
- allow each article in a series to link to all other articles in that series
- make the ordering intentional and maintainable
- consider future extensions to feeds, structured data, or metadata without requiring them in the first pass

## Out of scope

- creating a dedicated series landing page
- migrating all historical content into series immediately
- major redesign of article-page layout beyond what is needed for series support
- nested or hierarchical series models
- recommendation logic beyond explicit series relationships
- requiring feeds, structured data, or metadata support in the first pass

## Acceptance criteria

- [ ] Articles can declare series information in frontmatter
- [ ] Series metadata supports at least a series name and series order
- [ ] Supporting utilities exist as needed to group and sort articles in a series
- [ ] Article pages display series context when the article belongs to a series
- [ ] Articles in a series link to the other articles in that series
- [ ] Series ordering is stable and maintainable
- [ ] The implementation works without requiring a dedicated series page

## References

- https://shivjm.blog/colophon/how-i-create-an-article-series-in-eleventy/
