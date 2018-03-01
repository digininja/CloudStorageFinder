# Digital Ocean Space Finder

DO's Spaces are very similar to Amazon's Buckets and so Space Finder is a simple rewrite of the original Bucket Finder and works in the same way. Spaces currently have three regions, New York, Amsterdam and Singapore but, unlike Amazon, they do not do a redirect if you request a Space on a wrong region so the only way to find out if a Space exists is to test for it on all three regions. Space Finder therefore gives you an option to specify a single region or to test all three at the same time.

Two additional new features are to hide private Spaces and non-existent ones with the --hide-private and --hide-not-found parameters, I'll try to backport these to Bucket Finder as well to keep them consistent.

I've ran a few tests and already found some interesting content so I know there is good stuff out there to be found, it will just take the right word lists. Good luck!
