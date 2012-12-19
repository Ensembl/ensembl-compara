<span class="comp_tut kwa">use</span> strict<span class="comp_tut opt">;</span>
<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">;</span>
<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Utils<span class="comp_tut opt">::</span>Exception <span class="comp_tut kwc">qw</span><span class="comp_tut opt">(</span>throw<span class="comp_tut opt">);</span>
<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>SimpleAlign<span class="comp_tut opt">;</span>
<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>AlignIO<span class="comp_tut opt">;</span>
<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>LocatableSeq<span class="comp_tut opt">;</span>
<span class="comp_tut kwa">use</span> Getopt<span class="comp_tut opt">::</span>Long<span class="comp_tut opt">;</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$usage</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwc">qq</span><span class="comp_tut opt">{</span>
perl DumpMultiAlign<span class="comp_tut opt">.</span>pl
  Getting help<span class="comp_tut opt">:</span>
    <span class="comp_tut opt">[--</span>help<span class="comp_tut opt">]</span>

  For the query slice<span class="comp_tut opt">:</span>
    <span class="comp_tut opt">[--</span>species species<span class="comp_tut opt">]</span>
        Query species<span class="comp_tut opt">.</span> Default is <span class="comp_tut str">&quot;human&quot;</span>
    <span class="comp_tut opt">[--</span>coord_system coordinates_name<span class="comp_tut opt">]</span>
        Query coordinate <span class="comp_tut kwc">system</span><span class="comp_tut opt">.</span> Default is <span class="comp_tut str">&quot;chromosome&quot;</span>
    <span class="comp_tut opt">--</span>seq_region region_name
        Query region name<span class="comp_tut opt">,</span> i<span class="comp_tut opt">.</span>e<span class="comp_tut opt">.</span> the chromosome name
    <span class="comp_tut opt">--</span>seq_region_start start
    <span class="comp_tut opt">--</span>seq_region_end end

  For the alignments<span class="comp_tut opt">:</span>
    <span class="comp_tut opt">[--</span>alignment_type method_link_name<span class="comp_tut opt">]</span>
        The type of alignment<span class="comp_tut opt">.</span> Default is <span class="comp_tut str">&quot;BLASTZ_NET&quot;</span>
    <span class="comp_tut opt">[--</span>set_of_species species1<span class="comp_tut opt">:</span>species2<span class="comp_tut opt">:</span>species3<span class="comp_tut opt">:...]</span>
        The list of species used to get those alignments<span class="comp_tut opt">.</span> Default is
        <span class="comp_tut str">&quot;human:mouse&quot;</span><span class="comp_tut opt">.</span> The names should correspond to the name of the
        core database in the registry_configuration_file <span class="comp_tut kwc">or</span> any of its
        aliases

  Ouput<span class="comp_tut opt">:</span>
    <span class="comp_tut opt">[--</span>output_format clustalw<span class="comp_tut opt">|</span>fasta<span class="comp_tut opt">|...]</span>
        The type of output you want<span class="comp_tut opt">.</span> <span class="comp_tut str">&quot;clustalw&quot;</span> is the <span class="comp_tut kwa">default</span><span class="comp_tut opt">.</span>
    <span class="comp_tut opt">[--</span>output_file filename<span class="comp_tut opt">]</span>
        The name of the output file<span class="comp_tut opt">.</span> By <span class="comp_tut kwa">default</span> the output is the
        standard output
<span class="comp_tut opt">};</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$species</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">&quot;human&quot;</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$coord_system</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">&quot;chromosome&quot;</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$seq_region</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">&quot;14&quot;</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$seq_region_start</span> <span class="comp_tut opt">=</span> <span class="comp_tut num">75000000</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$seq_region_end</span> <span class="comp_tut opt">=</span> <span class="comp_tut num">75010000</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$alignment_type</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">&quot;BLASTZ_NET&quot;</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$set_of_species</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">&quot;human:mouse&quot;</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$output_file</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwc">undef</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$output_format</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">&quot;clustalw&quot;</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$help</span><span class="comp_tut opt">;</span>

GetOptions<span class="comp_tut opt">(</span>
    <span class="comp_tut str">&quot;help&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$help</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;species=s&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$species</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;coord_system=s&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$coord_system</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;seq_region=s&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$seq_region</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;seq_region_start=i&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$seq_region_start</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;seq_region_end=i&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$seq_region_end</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;alignment_type=s&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$alignment_type</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;set_of_species=s&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$set_of_species</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;output_format=s&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$output_format</span><span class="comp_tut opt">,</span>
    <span class="comp_tut str">&quot;output_file=s&quot;</span> <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut kwb">$output_file</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Print Help and exit</span>
<span class="comp_tut kwa">if</span> <span class="comp_tut opt">(</span><span class="comp_tut kwb">$help</span><span class="comp_tut opt">) {</span>
    <span class="comp_tut kwc">print</span> <span class="comp_tut kwb">$usage</span><span class="comp_tut opt">;</span>
    <span class="comp_tut kwa">exit</span><span class="comp_tut opt">(</span><span class="comp_tut num">0</span><span class="comp_tut opt">);</span>
<span class="comp_tut opt">}</span>

<span class="comp_tut kwa">if</span> <span class="comp_tut opt">(</span><span class="comp_tut kwb">$output_file</span><span class="comp_tut opt">) {</span>
    <span class="comp_tut kwc">open</span><span class="comp_tut opt">(</span>STDOUT<span class="comp_tut opt">,</span> <span class="comp_tut str">&quot;&gt;$output_file&quot;</span><span class="comp_tut opt">)</span> <span class="comp_tut kwc">or die</span><span class="comp_tut opt">(</span><span class="comp_tut str">&quot;Cannot open $output_file&quot;</span><span class="comp_tut opt">);</span>
<span class="comp_tut opt">}</span>

Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">load_registry_from_db</span><span class="comp_tut opt">(</span>
    <span class="comp_tut opt">-</span>host <span class="comp_tut opt">=&gt;</span> <span class="comp_tut str">'ensembldb.ensembl.org'</span><span class="comp_tut opt">, -</span>user <span class="comp_tut opt">=&gt;</span> <span class="comp_tut str">'anonymous'</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Getting all the Bio::EnsEMBL::Compara::GenomeDB objects</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$genome_dbs</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$genome_db_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span>
    <span class="comp_tut str">'Multi'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'compara'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'GenomeDB'</span><span class="comp_tut opt">);</span>

throw<span class="comp_tut opt">(</span><span class="comp_tut str">&quot;Cannot connect to Compara&quot;</span><span class="comp_tut opt">)</span> <span class="comp_tut kwa">if</span> <span class="comp_tut opt">(!</span><span class="comp_tut kwb">$genome_db_adaptor</span><span class="comp_tut opt">);</span>

<span class="comp_tut kwa">foreach</span> <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$this_species</span> <span class="comp_tut opt">(</span><span class="comp_tut kwc">split</span><span class="comp_tut opt">(</span><span class="comp_tut str">&quot;:&quot;</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$set_of_species</span><span class="comp_tut opt">)) {</span>
    <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$this_meta_container_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span>
        <span class="comp_tut kwb">$this_species</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'core'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'MetaContainer'</span><span class="comp_tut opt">);</span>

    throw<span class="comp_tut opt">(</span><span class="comp_tut str">&quot;Registry configuration file has no data for connecting to &lt;$this_species&gt;&quot;</span><span class="comp_tut opt">)</span>
        <span class="comp_tut kwa">if</span> <span class="comp_tut opt">(!</span><span class="comp_tut kwb">$this_meta_container_adaptor</span><span class="comp_tut opt">);</span>

    <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$this_production_name</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$this_meta_container_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_production_name</span><span class="comp_tut opt">;</span>

    <span class="comp_tut slc"># Fetch Bio::EnsEMBL::Compara::GenomeDB object</span>
    <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$genome_db</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$genome_db_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_name_assembly</span><span class="comp_tut opt">(</span><span class="comp_tut kwb">$this_production_name</span><span class="comp_tut opt">);</span>

    <span class="comp_tut slc"># Add Bio::EnsEMBL::Compara::GenomeDB object to the list</span>
    <span class="comp_tut kwc">push</span><span class="comp_tut opt">(</span>&#64;<span class="comp_tut kwb">$genome_dbs</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$genome_db</span><span class="comp_tut opt">);</span>
<span class="comp_tut opt">}</span>

<span class="comp_tut slc"># Getting Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$method_link_species_set_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span>
    <span class="comp_tut str">'Multi'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'compara'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'MethodLinkSpeciesSet'</span><span class="comp_tut opt">);</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$method_link_species_set</span> <span class="comp_tut opt">=</span>
    <span class="comp_tut kwb">$method_link_species_set_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_method_link_type_GenomeDBs</span><span class="comp_tut opt">(</span>
      <span class="comp_tut kwb">$alignment_type</span><span class="comp_tut opt">,</span> 
      <span class="comp_tut kwb">$genome_dbs</span><span class="comp_tut opt">);</span>

throw<span class="comp_tut opt">(</span><span class="comp_tut str">&quot;The database do not contain any $alignment_type data for $set_of_species!&quot;</span><span class="comp_tut opt">)</span>
    <span class="comp_tut kwa">if</span> <span class="comp_tut opt">(!</span><span class="comp_tut kwb">$method_link_species_set</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Fetching the query Slice:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$slice_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span><span class="comp_tut kwb">$species</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'core'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'Slice'</span><span class="comp_tut opt">);</span>

throw<span class="comp_tut opt">(</span><span class="comp_tut str">&quot;Registry configuration file has no data for connecting to &lt;$species&gt;&quot;</span><span class="comp_tut opt">)</span>
    <span class="comp_tut kwa">if</span> <span class="comp_tut opt">(!</span><span class="comp_tut kwb">$slice_adaptor</span><span class="comp_tut opt">);</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$query_slice</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$slice_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_region</span><span class="comp_tut opt">(</span><span class="comp_tut str">'toplevel'</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$seq_region</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$seq_region_start</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$seq_region_end</span><span class="comp_tut opt">);</span>

throw<span class="comp_tut opt">(</span><span class="comp_tut str">&quot;No Slice can be created with coordinates $seq_region:$seq_region_start-&quot;</span><span class="comp_tut opt">.</span>
    <span class="comp_tut str">&quot;$seq_region_end&quot;</span><span class="comp_tut opt">)</span> <span class="comp_tut kwa">if</span> <span class="comp_tut opt">(!</span><span class="comp_tut kwb">$query_slice</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Fetching all the GenomicAlignBlock corresponding to this Slice:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$genomic_align_block_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span>
    <span class="comp_tut str">'Multi'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'compara'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'GenomicAlignBlock'</span><span class="comp_tut opt">);</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$genomic_align_blocks</span> <span class="comp_tut opt">=</span>
    <span class="comp_tut kwb">$genomic_align_block_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_all_by_MethodLinkSpeciesSet_Slice</span><span class="comp_tut opt">(</span>
      <span class="comp_tut kwb">$method_link_species_set</span><span class="comp_tut opt">,</span> 
      <span class="comp_tut kwb">$query_slice</span><span class="comp_tut opt">);</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$all_aligns</span><span class="comp_tut opt">;</span>

<span class="comp_tut slc"># Get a Bio::SimpleAlign object from every GenomicAlignBlock</span>
<span class="comp_tut kwa">foreach</span> <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$this_genomic_align_block</span> <span class="comp_tut opt">(</span>&#64;<span class="comp_tut kwb">$genomic_align_blocks</span><span class="comp_tut opt">) {</span>
    <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$simple_align</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$this_genomic_align_block</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_SimpleAlign</span><span class="comp_tut opt">;</span>
    <span class="comp_tut kwc">push</span><span class="comp_tut opt">(</span>&#64;<span class="comp_tut kwb">$all_aligns</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$simple_align</span><span class="comp_tut opt">);</span>
<span class="comp_tut opt">}</span>

<span class="comp_tut slc"># print all the genomic alignments using a Bio::AlignIO object</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$alignIO</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>AlignIO<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">newFh</span><span class="comp_tut opt">(</span>
    <span class="comp_tut opt">-</span>interleaved <span class="comp_tut opt">=&gt;</span> <span class="comp_tut num">0</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>fh <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut opt">*</span>STDOUT<span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>format <span class="comp_tut opt">=&gt;</span> <span class="comp_tut kwb">$output_format</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>idlength <span class="comp_tut opt">=&gt;</span> <span class="comp_tut num">10</span>
<span class="comp_tut opt">);</span>
  
<span class="comp_tut kwa">foreach</span> <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$this_align</span> <span class="comp_tut opt">(</span>&#64;<span class="comp_tut kwb">$all_aligns</span><span class="comp_tut opt">) {</span>
    <span class="comp_tut kwc">print</span> <span class="comp_tut kwb">$alignIO $this_align</span><span class="comp_tut opt">;</span>
<span class="comp_tut opt">}</span>

<span class="comp_tut kwa">exit</span><span class="comp_tut opt">;</span>
