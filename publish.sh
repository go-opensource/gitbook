# !bash

if [ "$1" == "" ]; then
	echo "!! Empty commit message. Enter the commit message as a first bash param."
	exit 1
fi

gitbook build &&
git checkout gh-pages &&
cp -R _book/* . &&
git clean -fx _book &&
git add . &&
git commit -a -m "$1" &&
git pull origin gh-pages --rebase &&
git push origin gh-pages





