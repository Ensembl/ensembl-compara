<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$query_species</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">'human'</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$seq_region</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">'14'</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$seq_region_start</span> <span class="comp_tut opt">=</span> <span class="comp_tut num">75000000</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$seq_region_end</span>   <span class="comp_tut opt">=</span> <span class="comp_tut num">75010000</span><span class="comp_tut opt">;</span>

<span class="comp_tut slc"># Getting the Slice adaptor:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$slice_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span>
    <span class="comp_tut kwb">$query_species</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'core'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'Slice'</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Fetching a Slice object:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$query_slice</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$slice_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_region</span><span class="comp_tut opt">(</span>
    <span class="comp_tut str">'toplevel'</span><span class="comp_tut opt">,</span>
    <span class="comp_tut kwb">$seq_region</span><span class="comp_tut opt">,</span>
    <span class="comp_tut kwb">$seq_region_start</span><span class="comp_tut opt">,</span>
    <span class="comp_tut kwb">$seq_region_end</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># Fetching all the GenomicAlignBlock corresponding to this Slice:</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$genomic_align_blocks</span> <span class="comp_tut opt">=</span>
    <span class="comp_tut kwb">$genomic_align_block_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_all_by_MethodLinkSpeciesSet_Slice</span><span class="comp_tut opt">(</span>
      <span class="comp_tut kwb">$human_mouse_blastz_net_mlss</span><span class="comp_tut opt">,</span>
      <span class="comp_tut kwb">$query_slice</span><span class="comp_tut opt">);</span>
