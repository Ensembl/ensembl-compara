<span class="comp_tut slc"># first you have to get a Member object. In case of homology is a gene, in </span>
<span class="comp_tut slc"># case of family it can be a gene or a protein</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$member_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span><span class="comp_tut str">'Multi'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'compara'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'Member'</span><span class="comp_tut opt">);</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$member</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$member_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_by_source_stable_id</span><span class="comp_tut opt">(</span><span class="comp_tut str">'ENSEMBLGENE'</span><span class="comp_tut opt">,</span><span class="comp_tut str">'ENSG00000004059'</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># then you get the homologies where the member is involved</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$homology_adaptor</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_adaptor</span><span class="comp_tut opt">(</span><span class="comp_tut str">'Multi'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'compara'</span><span class="comp_tut opt">,</span> <span class="comp_tut str">'Homology'</span><span class="comp_tut opt">);</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$homologies</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$homology_adaptor</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">fetch_all_by_Member</span><span class="comp_tut opt">(</span><span class="comp_tut kwb">$member</span><span class="comp_tut opt">);</span>

<span class="comp_tut slc"># That will return a reference to an array with all homologies (orthologues in</span>
<span class="comp_tut slc"># other species and paralogues in the same one)</span>
<span class="comp_tut slc"># Then for each homology, you can get all the Members implicated</span>

<span class="comp_tut kwa">foreach</span> <span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$homology</span> <span class="comp_tut opt">(</span>&#64;<span class="comp_tut opt">{</span><span class="comp_tut kwb">$homologies</span><span class="comp_tut opt">}) {</span>
  <span class="comp_tut slc"># You will find different kind of description</span>
  <span class="comp_tut slc"># UBRH, MBRH, RHS, YoungParalogues</span>
  <span class="comp_tut slc"># see ensembl-compara/docs/docs/schema_doc.html for more details</span>

  <span class="comp_tut kwc">print</span> <span class="comp_tut kwb">$homology</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">description</span><span class="comp_tut opt">,</span><span class="comp_tut str">&quot; &quot;</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$homology</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">subtype</span><span class="comp_tut opt">,</span><span class="comp_tut str">&quot;</span><span class="comp_tut esc">\n</span><span class="comp_tut str">&quot;</span><span class="comp_tut opt">;</span>

  <span class="comp_tut slc"># And if they are defined dN and dS related values</span>

  <span class="comp_tut kwc">print</span> <span class="comp_tut str">&quot; dn &quot;</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$homology</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">dn</span><span class="comp_tut opt">,</span><span class="comp_tut str">&quot;</span><span class="comp_tut esc">\n</span><span class="comp_tut str">&quot;</span><span class="comp_tut opt">;</span>
  <span class="comp_tut kwc">print</span> <span class="comp_tut str">&quot; ds &quot;</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$homology</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">ds</span><span class="comp_tut opt">,</span><span class="comp_tut str">&quot;</span><span class="comp_tut esc">\n</span><span class="comp_tut str">&quot;</span><span class="comp_tut opt">;</span>
  <span class="comp_tut kwc">print</span> <span class="comp_tut str">&quot; dnds_ratio &quot;</span><span class="comp_tut opt">,</span> <span class="comp_tut kwb">$homology</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">dnds_ratio</span><span class="comp_tut opt">,</span><span class="comp_tut str">&quot;</span><span class="comp_tut esc">\n</span><span class="comp_tut str">&quot;</span><span class="comp_tut opt">;</span>
<span class="comp_tut opt">}</span>
