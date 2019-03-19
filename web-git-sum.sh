#!/bin/bash -e

URL="https://git.mitxela.com/"

# Number of commits messages to display
NUMCOMMITS=50

# Markdown parser for readme files
MARKDOWN="md2html --fpermissive-autolinks"


#####
function escapeHTML() {
	sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' 
}

function human(){
	awk '{ split( "B K M G" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf("%.4g%s", $1, v[s]) }'
}

function chkDesc(){
	description=$(cat $1 2>/dev/null || echo "No description provided")
	if [[ "$description" == "Unnamed repository; edit this file 'description' to name the repository." ]]; then description="No description provided"; fi
	echo "$description"
}

function toTable() {
	fields=$(cat /dev/stdin)
	fields="${fields//$'\n\n'/<\/td><\/tr><tr><td>}"
	fields="${fields//$'\n'/<\/td><td>}"

	echo "<table><tr>"
	for th in "$@"; do echo "<th>$th</th>"; done
	echo "</tr><tr><td>${fields}</td></tr></table>"
}

function ansi2html(){
        # This is a complete hack, but it seems to work well enough for the output of git log
        sed -E 's|\[0?m|</span>|g' |\
        perl -pe 's|\[([0-9;]+)m|"<span class=\"c".($1=~s/;/t/gr)."\">"|ge' |\
        sed 's,</span></span>,</span>,g'
}

repo=$(basename $(pwd))
name=$(basename $(pwd) .git)

description=$(chkDesc description)

branches=$(git for-each-ref --format='%(refname:short)%0a%(committerdate:iso)%0a%(authorname)%0a' refs/heads | escapeHTML | toTable "Name" "Last commit date" "Author")

tags=$(git for-each-ref --format='%(refname:short)%0a%(committerdate:iso)%0a%(authorname)%0a' refs/tags)
if [[ "$tags" ]]; then 
	tags=$(echo "$tags" | escapeHTML | toTable "Name" "Last commit date" "Author"); 
	tags="<h2>Tags</h2>$tags"
fi


files=$(git -c core.quotePath=false ls-tree --full-tree --name-only -r HEAD)


readme=$(grep -im1 readme <<< "$files" || true)
if [[ "$readme" ]]; then
	readme="<hr><b>Contents of $readme:</b><div id=readme>"$(git show HEAD:$readme | eval "$MARKDOWN")"</div>"
fi

while read -r file; do
	filelist+=$(echo "$file" | escapeHTML | sed -E 's|(.+)/|<span class=dir>\1/</span>|g')$'\n'
	filelist+=$( (git cat-file -s "HEAD:$file" || echo - ) | human)$'\n\n'
done <<< "$files"

filelist=$(toTable Name Size <<< "$filelist")

#commits=$(git log --format="%h%n%s%n%an%n%ad%n" --date=format:'%Y-%m-%d %H:%M' -$NUMCOMMITS | escapeHTML | toTable "Hash" "Commit message" "Author" "Date")

commits="<div id=graph>"$(git log --format="%C(ul)%h%C(auto)%d%C(reset)%n%C(bold)%an%C(reset) %ad%n%s%n" --date=format:'%Y-%m-%d %H:%M' --graph --all --color=always -$NUMCOMMITS | escapeHTML | ansi2html)"</div>"

hidden=$(( $(git rev-list --all --count) - "$NUMCOMMITS" ))

if [[ $hidden -eq "1" ]]; then commits+="[ $hidden commit remaining ]"; fi
if [[ $hidden -gt "1" ]]; then commits+="[ $hidden commits remaining ]"; fi

style=$(cat << EOF
<style>
body{
  color:#000;
  background:#fff;
  font-family: monospace;
}
code, pre{
  background:#eee;
  padding:3px;
}
h1,h2,h3,h4,h5,h6 {
  margin:0
}
hr {
  border: 1px solid #aaa;
}
img{
  float:left;
  border:0;
  margin-right:10px;
}
#url{
  white-space:pre
}
#readme{
  padding:1%;
  font-family: sans-serif;
}
table{
  text-align: left;
  min-width:600px;
}
tr:hover td {
  background: #eee;
}
#log + table td:first-child, .dir, #desc{
  color:#888;
}
@media(max-width:800px){
  td,tr,table{display:block;min-width:auto}
  th{display:none}
  tr{margin:1em 0}
  td:first-child{font-size:large}
}
#graph{white-space:pre-wrap}
.c1, .c1t32, .c1t33, .c1t36, .c31, .c32, .c33, .c34, .c35, .c36 {font-weight:bold}
.c4   {color:grey}
.c1t32{color:blue}
.c1t33{color:green}
.c1t36{color:orange}
.c31{color:red}
.c32{color:orange}
.c33{color:green}
.c34{color:magenta}
.c35{color:blue}
.c36{color:cyan}
</style>
EOF
)

{
cat << EOF
<!doctype html>
<meta name=viewport content="width=device-width, initial-scale=1.0">
<title>$name</title>
$style
<a href=$URL><img src=/logo.jpg></a>
<h1>$name</h1>
<div id=desc>$description</div>
<div id=url>git clone ${URL}${repo}</div>
<a href=#log>Log</a> | <a href=#files>Files</a> | <a href=#refs>Refs</a>
EOF
if [[ "$readme" ]]; then echo " | <a href=#readme>README</a>"; fi

echo "<hr>"
echo "<h2 id=refs>Branches</h2>$branches $tags<hr>"
echo "<h2 id=files>File Tree (HEAD)</h2>$filelist<hr>"
echo "<h2 id=log>History</h2>$commits"
echo "$readme"

} > "index.htm"


# generate repository index
if [[ "$*" =~ "no-index" ]]; then exit; fi

cd ..

{
cat << EOF
<!doctype html>
<meta name=viewport content="width=device-width, initial-scale=1.0">
<title>Repositories</title>
$style
<h2>Repositories</h2>
<hr>
EOF

{ for repo in *.git; do
	name=$(basename $repo .git)
	echo "<a href='$name'>$name</a>"
	echo $(chkDesc "$repo/description")
	echo $(git --git-dir="$repo" log -1 --format='%ad' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null || echo -e $'-\n' )
	echo
done } | toTable Name Description "Last commit"


} > "index.htm"
