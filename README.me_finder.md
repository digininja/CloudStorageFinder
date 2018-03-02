# Mobile Me Finder

Copyright(c) 2011, Robin Wood <robin@digininja.org>

My Bucket Finder project was recently featured on Hak5 and one of the feedback
messages mentioned that Mobile Me works in the same way as Amazon S3 and lets
users access their public accounts through URLs in the form

https://public.me.com/<account name>

This tool is a modification of Bucket Finder to run through Mobile Me accounts.

I've also written up the research and results in a couple of blog posts:

* [Mobile Me Madness](http://www.digininja.org/blog/mobile_me_madness.php)
* [Analysing Mobile Me](http://www.digininja.org/blog/analysing_mobile_me.php)

## Version
1.0 - Release

## Installation
I don't think it needs anything more than the built in modules so you shouldn't
need to install any gems. Just grab the file, make it executable and run it.

I've tested it in Ruby 1.8.7 and 1.9.1 so there should be no problems with versions.

## Usage
Basic usage is simple, just start it with a wordlist:

```
./me_finder.rb my_words
```

And it will go off and do your bidding.

You can also specify the --download option to download all public files found.
Be careful with this as there are a lot of large files out there. I'd personally
do the general search then only use this option with a select subset of account
names:

```
./me_finder.rb --download my_words
```

The files are downloaded into a folder with the account name and then the
appropriate structure from the site.

If you want to log the output to a file you can use the --log-file option:

```
./me_finder.rb --log-file me_output.log my_words
```

## Licence

This project released under the GNU GENERAL PUBLIC LICENSE Version 3.
