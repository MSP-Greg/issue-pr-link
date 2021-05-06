# issue-pr-link

### Purpose

This repo contains Ruby scripts to add links for PR's and issues in history/changelog markdown files.  It also adds minimal hover text to the links.  See https://github.com/puma/puma/blob/master/History.md for an example.

Links in markdown are enclosed in brackets.  For your history/changelog markdown file, format new entires like:
```
Your change here (#2341, #2315)
```

Running the code here will change it to:
```
Your change here ([#2341], [#2315])
```
and add the link info at the bottom of the document.

The code uses the GitHub GraphQL API to retrieve the pr/issue data, and stores it in a JSON file located in this repo.  The files are named 'data_\<repo\>.json' and are excluded with .gitignore.

### Create a GitHub 'Personal access tokens' & JSON info file

Using the GitHub GraphQL API requires a 'token', so you may need to create one for access.  To create one, go to your account page, follow 'Settings / Developer settings / Personal access tokens', then click 'Generate new token'.  I believe allowing only 'public_repo' is enough to use the API and retrieve data.  Save the 40 character token.

There is a json sample file in the repo named `info.sample`.  Copy (rename as needed) that to a folder outside of the repo, and set the items as needed, in particular, your token.

### Running the code

There are three Ruby scripts.  All thre should be run from the One will output the text for a new release to be used in History.md, and the other two are used to download the data and update your History/ChangeLog file.  All scripts take the path to your json info file as a first parameter.

**`history_new_release.rb`** - this file outputs suggested text for a new release, and also lists commits not added to the text.  The json info file should be the first parameter, and the last release tag should be the second parameter.  The code reads the `labels` array in the json info file, and uses it to filter the commits/PR's into categories in the release text.  It also has a limit of 100 commits between releases.

The `labels` array is an array of arrays.  The inner arrays have two elements, the first is the label string from the PR, the second is the text used for the 'history' group header.

**`json_pr_issue_all.rb`** - this file needs to be run first. It downloads all the data for every PR and issue for your repo.  This may need to be run if your data gets too out of date.

**`json_history_update.rb`** - this is the file that updates the history/changelog links.  First, it downloads the most recent 100 closed and open PR's and issues (four sets of 100), and adds/updates them to the locally stored data. It then opens the history/changelog file, parses it, and regenerates all of the link info at the bottom.

### Notes

#### Paths

I normally run this from the folder containing the repo's history/changelog file.  When run that way, the json info file only needs the filename.  If you run the script from another folder, include the full path to the history/changelog file in your json info file.

#### Connections

At present, this uses a new SSL connection for every set of 100 records retrieved with the GitHub GraphQL API.  I haven't looked for connection limits, I may change it to use fewer connections in the future.  The connections are set to 'OpenSSL::SSL::VERIFY_PEER'.
