=head1 SYNOPSIS

package GO::CGI::Definitions;

Gives definitions of words encountered in the
HTML browser, IE "What is ISS?"

=head2 get_def

  Usage     - GO::CGI::Definition->get_def(-word=>'ISS');
  Arguments - -word
  returns   - String

Takes a word and returns a list of definitions.

=cut

package GO::CGI::Definitions;

use GO::Utils qw(rearrange);

sub get_def{
  my $self = shift;
  my ($word) =
	rearrange([qw(word)], @_);

  #  This is kind of lame.  I'd like to have a better
  #  infrastructure for this kind of thing.  RDF here we come.
  
  my %defs = {};
  
  %defs->{'query_options'} = [ 
   'By selecting "Terms" in the query options, 
   you are choosing to search by the name, 
   definition or accession of a GO term.',

   'If you choose "Gene products" you are opting
   to search based on the gene symbol of a gene
   product which has been annotated to a term.',
			      
   'The Exact Match box prevents the addition of wild cards to the
   beginning and ending of your search, so :
   endoplasm does not becomes *endoplasm*',

   ];

  %defs->{'advanced_query_options'} = [ 
   'By selecting "Terms" in the query options, 
   you are choosing to search by the name, 
   definition or accession of a GO term.',

   'If you choose "Gene products" you are opting
   to search based on the gene symbol of a gene
   product which has been annotated to a term.',
			      
   'The Exact Match box prevents the addition of wild cards to the
   beginning and ending of your search, so :
   endoplasm does not becomes *endoplasm*',

   'The Fields pulldown allows you to select which aspects
    of the GO terms/associated gene products you would like to search.
    You can search the names, synonyms, IDs, and External References
    of GO terms.  You can search Gene Symbol or Full gene name of an
    associated gene product.',

   'The Datasource option is only available for a gene product 
    search.  This specifies which datasources gene products you would 
    like to query.',

   'The Evidence Type option is only available for gene product
    queries.  When an evidence type is selected, only gene products
    associated to terms with that type of evidence will be found.
    The evidence type "Curator Approved" will select all types of evidence 
    with the exception of "Inferred by Electronic Annotation".  This is
    because IEA is the only association evidence type that is never looked 
    at by a curator.  By default only "Curator Approved" gene product
    associations are selected due to the sheer number of IEA types.' 

   ];	       

  %defs->{'batch'} = [
    'The batch query allows you to enter multiple
     terms and/or gene products.  Seperate all terms
     with a newline character.'
   ];
  
#   'IMP - inferred from mutant phenotype',
#   'ISS - inferred from sequence similarity',
#   'IGI - inferred from genetic interaction',
#   'IPI - inferred from physical interaction',
#   'IDA - inferred from direct assay',
#   'IEP - inferred from expression pattern',
#   'IEA - inferred from electronic annotation',
#   'TAS - traceable author statement',
#   'NAS - non-traceable author statement',


%defs->{'ev_codes'} = q [
<h2>Evidence Codes</h2>
<ul>

<li><b>IDA</b> inferred from direct assay
   <ul>
<li>Enzyme assays
   <li>In vitro reconstitution (e.g. transcription)
   <li>Immunofluorescence (for cellular component)
   <li>Cell fractionation (for cellular component)
   <li>Physical interaction/binding assay (sometimes appropriate for cellular component)
   </ul>
Comment: need to be careful in that an experiment considered as direct
   assay for one ontology may be a different kind of evidence for the
   other ontologies. In particular, we thought of more kinds of direct
   assays for cellular component component than for function or
   process. For example, a fractionation experiment might provide "direct
   assay" evidence that a gene product is in the nucleus, but "protein
   interaction" evidence for its function or process.<p>

<li><b>IEA</b> inferred from electronic annotation
   <ul>
<li>Annotations based on "hits" in sequence similarity searchs, if they have not been reviewed by curators (curator-reviewed hits would get ISS)
   <li>Annotations transferred from database records, if not reviewed by curators (curator-reviewed items may use NAS, or the reviewing process may lead to print references for the annotation)
   </ul>

Comment: Used for annotations that depend directly on computation
   or automated transfer of annotations from a database. The key
   feature that distinguishes this evidence code from others is
   <i>what a curator has done</i>--IEA is used when no curator has
   checked the annotation to verify its accuracy. The actual method
   used (BLAST search, UniProt/SwissProt keyword mapping, etc.) doesn't matter.

<p>

<li><b>IEP</b> inferred from expression pattern
   <ul>
<li>Transcript levels (e.g. Northerns, microarray data)
   <li>Protein levels (e.g. Western blots)
   </ul>

Comment: Covers cases where the annotation is inferred from the
   timing or location of expression of a gene. Expression data will be
   most useful for process annotation rather than function. For
   example, several of the heat shock proteins are thought to be
   involved in the process of stress response because they are
   upregulated during stress conditions. Use this category with
   caution! Also see the <a
href="GO.evidence.html#expression">additional notes</a> below.<p>

Note: The "database identifier" column in the gene_association file
   should be filled in whenever possible, to help avoid circular
   annotations between GO and other databases.<p>

<li><b>IGI</b> inferred from genetic interaction
   <ul>
<li>"Traditional" genetic interactions such as suppressors, synthetic lethals, etc.
   <li>Functional complementation
   <li>Rescue experiments
   <li>Inference about one gene drawn from the phenotype of a mutation in a different gene
   </ul>

Comment: Includes any combination of alterations in the sequence
   (mutation) or expression of more than one gene/gene product. This
   category can therefore cover any of the IMP experiments that are
   done in a non-wild-type background, though we prefer to use it only
   when all mutations are documented. When redundant copies of a gene
   must all be mutated to see an informative phenotype, that's
   IGI. (Yes, we know that means some organisms, such as mouse, will
   have far, far more IGI than IMP annotations.)
   <p>
We have also decided to use this category for situations where a
   mutation in one gene (gene A) provides information about the
   function, process, or component of another gene (gene B;
   i.e. annotate gene B using IGI).

<p>

We recommend making an entry in the "with" column when using this
   evidence code (i.e. include an identifier for the "other" gene
   involved in the interaction). If more than one independent genetic
   interaction supports the association, use separate lines for
   each. In cases where the gene of interest interacts simultaneously
   with more than one other gene, put both/all of the interacting
   genes on the same line (separate identifiers by commas in the
   "with" column). To help clarify:

   <pre>
GOterm   IGI    FB:gene1,FB:gene2

    means that the GO term is supported by evidence from its interaction
    with *both* of these genes; i.e. neither of these statements are true:

    GOterm  IGI     FB:gene1
    GOterm  IGI     FB:gene2 
   </pre>

See the <a
href="http://www.geneontology.org/GO.doc.html#annot">general
   documentation section</a> of the association file for more
   information.

<p>

<li><b>IMP</b> inferred from mutant phenotype
   <ul>
<li>Any gene mutation/knockout
   <li>Overexpression/ectopic expression of wild-type or mutant genes
   <li>Anti-sense experiments
   <li>RNAi experiments
   <li>Specific protein inhibitors
   </ul>
Comment: anything that is concluded from looking at mutations or
   abnormal levels of the product(s) only of the gene of interest is
   IMP (compare IGIs).<p>

<li><b>IPI</b> inferred from physical interaction
   <ul>
<li>2-hybrid interactions
   <li>Co-purification
   <li>Co-immunoprecipitation
   <li>Ion/protein binding experiments
   </ul>

Comment: Covers physical interactions between the gene product of
   interest and another molecule (or ion, or complex). For both IPI and
   IGI, it would be good practice to qualify them with the
   gene/protein/ion. We thought that antibody binding experiments were
   not suitable as evidence for function or process.<p>
<p>

We recommend making an entry in the "with" column when using this
   evidence code (i.e. include an identifier for the "other" protein
   involved in the interaction). If more than one independent physical
   interaction supports the association, use separate lines for
   each. In cases where the gene product of interest interacts
   simultaneously with more than one other protein, put both/all of
   the interacting things on the same line (separate identifiers by
   commas in the "with" column). To help clarify:

   <pre>
GOterm   IPI    DB:id1,DB:id2

    means that the GO term is supported by evidence from its
    interaction with *both* of these proteins; i.e. neither of these
    statements are true:

    GOterm  IPI     DB:id1
    GOterm  IPI     DB:id2 
   </pre>

See the <a
href="http://www.geneontology.org/GO.doc.html#annot">general
   documentation section</a> of the association file for more
   information.

<p>

<li><b>ISS</b> inferred from sequence or structural similarity
   <ul>
<li>Sequence similarity (homologue of/most closely related to)
   <li>Recognized domains
   <li>Structural similarity
   <li>Southern blotting
   </ul>

Comment: Use this code for BLAST (or other sequence similarity
   detection method) results that have been reviewed for accuracy by a
   curator. If the result has not been reviewed, use IEA. ISS can
   also be used for sequence similarities reported in publishes
   papers, if the curator thinks the result is reliable enough. When
   the gene is a "homologue of," can infer fairly detailed function
   and location (cellular component) but err on the side of low
   resolution for processes. For recognized domains, attribution to
   any of the ontologies will probably be at low resolution.<p>

We recommend making an entry in the "with" column when using this
   evidence code (i.e. include an identifier for the similar
   sequence).

<p>
<li><b>NAS</b> non-traceable author statement
   <ul>
<li>Database entries that don't cite a paper (e.g. UniProt/SwissProt
records, YPD protein reports)
   <li>Statements in papers (abstract, introduction, or discussion)
that a curator cannot trace to another publication
   </ul>

Comment: Formerly NA (not available). See TAS, and see <a
href="GO.evidence.html#ass_vs_na">notes</a> below. Also, note that
   "author" can be interpreted quite loosely for this code--for
   example, one doesn't have to know which curator entered an
   untraceable statement that appears on a database record to use this
   code<p>

<li><b>TAS</b> traceable author statement
   <ul>
<li>Anything in a review article where the original experiments are
traceable through that article (material from introductions to
non-review papers will sometimes meet this standard)
   <li>Anything found in a text book or dictionary; usually text book
material has become common knowledge (e.g. "everybody" knows that
enolase is a glycolytic enzyme).
   </ul>

Comment: Formerly ASS ("author said so"). TAS and NAS are both used
   for cases where the publication that a curator uses to support an
   annotation doesn't show the evidence (experimental results,
   sequence comparison, etc.). TAS is meant for the more reliable
   cases, such as reviews (presumably written by experts) or material
   sufficiently well established to appear in a text book, but there
   isn't really a sharp cutoff between TAS and NAS. Curator discretion
   is advised! Also see <a href="GO.evidence.html#ass_vs_na">notes</a>
below.<p>

];

  return %defs->{$word};

}


1;
