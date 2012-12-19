<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>AlignIO<span class="comp_tut opt">;</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$simple_align</span> <span class="comp_tut opt">=</span> <span class="comp_tut kwb">$homology</span><span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">get_SimpleAlign</span><span class="comp_tut opt">();</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$alignIO</span> <span class="comp_tut opt">=</span> Bio<span class="comp_tut opt">::</span>AlignIO<span class="comp_tut opt">-&gt;</span><span class="comp_tut kwd">newFh</span><span class="comp_tut opt">(</span>
    <span class="comp_tut opt">-</span>interleaved <span class="comp_tut opt">=&gt;</span> <span class="comp_tut num">0</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>fh <span class="comp_tut opt">=&gt;</span> \<span class="comp_tut opt">*</span>STDOUT<span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>format <span class="comp_tut opt">=&gt;</span> <span class="comp_tut str">&quot;clustalw&quot;</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>idlength <span class="comp_tut opt">=&gt;</span> <span class="comp_tut num">20</span><span class="comp_tut opt">);</span>

<span class="comp_tut kwc">print</span> <span class="comp_tut kwb">$alignIO $simple_align</span><span class="comp_tut opt">;</span>
