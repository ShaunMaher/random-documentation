---
title: Customisations
---
## Remove the "Previous" and "Next" buttons from the "docs" pages
Open `website/src/css/custom.css` and add the following:
```
.pagination-nav {
  display: none;
}
```

## Show the last author and update date on a "docs" page (Note: not working yet)
In `website/docusaurus.config.js` add `showLastUpdateAuthor: true` and
`showLastUpdateTime: true` as shown below.

```
presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          ...
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
```

## Modified "Edit this page" url generation function to support GitLab
The default method Docusaurus uses to generate these links works fine for GitHub
but is not quite right if:
* You're using GitLab to host your "docs" repository
* Your "docs" repository is a git submodule, seperate from the repository that
  holds the Docusaurus code/configuration.

The following works for my case.

In `website/docusaurus.config.js`, in the `presets` -> `docs` section, replace:
```
editUrl:
            'https://github.com/facebook/docusaurus/tree/main/packages/create-docusaurus/templates/shared/',
```
with
```
editUrl: ({locale, docPath}) => {
            return `https://git.ghanima.net/documentation/random-documentation/-/blob/main/${docPath}`;
          },
```

