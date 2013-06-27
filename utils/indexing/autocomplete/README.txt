Hi Steve,

Here's the documentation for the autocomplete builder. It's a C-file. You build it like this

gcc -O3 autocomplete.c -o autocomplete -lm

It can take two arguments -n is the number of rows to generate. 1000000 is good. The files it makes aren't big (about twenty times the value of "n" in bytes), the issue is how big a file SOLR can cope with and the amount of memory that the builder needs during build.

I'm guessing it will take a couple of hours on all the XML files. The bigger files like variation don't take all that long -- gene seems to be the killer.

The other option is -c which is useful. It takes the list of files on stdin, one per line, ie same format as the output of find, so you can do, eg,

find /nfs/web_data/search/solr/data/ensembl/ensembl_71 -name \*_71_\*.xml | ./autocomplete -n 1000000 -c >dict.txt

You need to feed all the files from all the feature types and species in one go for it to work.

It produces the output on stdout which goes into

/www/java/solr/sanger/ensembl_core/conf

I've updated the solrconfig.xml on the mirror machines with two extra sections to make this work. When that's done, addresses like this will work

http://ec2-54-224-209-149.compute-1.amazonaws.com:8000/solr-sanger/ensembl_core/suggest?q=nic&spellcheck.build=true

If we forget why this was done in C, I reckon this will take a couple of hours to run: the original perl version would take somewhere around a month.

There's some (unexploited) opportunities for parallelism but it's not embarassingly parallel. The inter-thread communication required would be calculation and notification of "banned" terms as the program progresses. That doesn't need to be instant, but must be timely, because pruning early is how memory is kept in bounds. Overall, as the running time isn't all that bad, it doesn't seem worth it.

An alternative easy win would be to separate out the lexing (about 50% of time) into a thread separate from the managing of the index being built, by message-passing of lexed words: that would mean two threads doing different jobs and could double the speed. Speed is close to the speed of the disk, though, (it's not unusual to see the process in disk wait) so that may not be that big a win unless the indexes are moved to faster disk.

Dan. 

