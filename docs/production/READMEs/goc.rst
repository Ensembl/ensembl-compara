Gene-order conservation scores
==============================

Calculation of the GOC scores goes as follow:

#. The mlss id of an orthologous pair is used to retrieve the set of all homology id's.

   #. Each homology id is used to retrieve its gene members which are then separated by species and by chromosome into different lists where they are ordered by their dnafrag starts.
   #. Chromosomes/scaffolds that contains a single ortholog member are discarded as this means the goc score is NULL since they have no neighbours

#. We calculate a goc score for each ortholog gene member and take the highest score as the homology goc score.

   #. For each chromosome of each species, we loop through the ordered list of ortholog gene members.
   #. Each ortholog gene member is taking in turn and designated as the query ortholog.
   #. We then take two ortholog gene members to its left and two ortholog gene members to its right if they are there. To complete our window.
   #. This array of at most 5 ortholog gene members  including the query ortholog gene member is then sent to `_compute_ortholog_score` method

#. Here a new array is created which contains only the present neighbours. 

   #. We calculate the extreme dnafrag start and dnafrag end out of this new array.
   #. To account for inversions in the genome, we checks if both members of the query ortholog are in the same direction/ strand
   #. Get the all protein-coding gene members (ordered by their dnafrag start position)  spanning the extreme start and end range from above
   #. We collapse the tandem repeats in this list of genes

#. Now we will compare the ordered gene members. By checking that the order of the gene members that we get from the orthologs (Array1) match the order of the gene members (Array2) that we get from genome using the extreme dnafrag start and end after removing all tandem repeats.

   #. We locate the position of the query gene member in Array2 and called this the query_index.
   #. We checked if the gene member at query_index-1 matches the left1 gene member from Array1.
   #. If this returns false we check left1 gene member against  query_index-2. This means we allow for one insertion.
   #. We then check if query_index-2 or query_index-3 of Array2 matches left2 of Array1.
   #. We repeat b-d from about for right1 and right2 of Array1 against query_index+1,2,3 of Array2.
   #. Each match represents a goc score of 25%.

