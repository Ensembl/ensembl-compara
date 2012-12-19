<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">;</span>
Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Registry<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">load_registry_from_db</span><span class="comp_tut opt">(</span>
    <span class="comp_tut opt">-</span>host <span class="comp_tut opt">=&gt;</span> <span class="comp_tut str">'ensembldb.ensembl.org'</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>user <span class="comp_tut opt">=&gt;</span> <span class="comp_tut str">'anonymous'</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>port <span class="comp_tut opt">=&gt;</span> <span class="comp_tut num">5306</span><span class="comp_tut opt">);</span>
