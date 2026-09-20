# Wiki source

These pages are the source for the GitHub wiki. The wiki is a separate git
repository, and GitHub will not create it until the first page exists.

**To publish**, once you have created any page through the web UI at
https://github.com/vetkat/hattorio/wiki :

    make wiki

That clones the wiki repo, copies these files over, and pushes. Edit here and
re-run it rather than editing in the browser, so the pages stay under review
with everything else.
