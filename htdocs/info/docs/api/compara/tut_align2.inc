<span class="comp_tut slc"># Getting the GenomeDB adaptor:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$genome_db_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span>
    <span class="comp_tut str">'Multi'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'compara'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'GenomeDB'</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Fetching GenomeDB objects for human and mouse:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$human_genome_db</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$genome_db_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_name_assembly</span><span class="comp_tut opt">(</span><span class="comp_tut str">'homo_sapiens'</span><span class="comp_tut opt">);</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$mouse_genome_db</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$genome_db_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_name_assembly</span><span class="comp_tut opt">(</span><span class="comp_tut str">'mus_musculus'</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Getting the MethodLinkSpeciesSet adaptor:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$method_link_species_set_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span>
    <span class="comp_tut str">'Multi'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'compara'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'MethodLinkSpeciesSet'</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Fetching the MethodLinkSpeciesSet object corresponding to LASTZ_NET alignments between human and mouse genomic sequences:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$human_mouse_blastz_net_mlss</span> <span class="comp_tut opt">=</span>
    <span class="comp_tut kwb">$method_link_species_set_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_method_link_type_GenomeDBs</span><span class="comp_tut opt">(</span>
        <span class="comp_tut str">&quot;LASTZ_NET&quot;</span><span class="comp_tut opt">,</span>
        <span class="comp_tut opt">[</span><span class="comp_tut kwb">$human_genome_db</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$mouse_genome_db</span><span class="comp_tut opt">]</span>
    <span class="comp_tut opt">);</span>
