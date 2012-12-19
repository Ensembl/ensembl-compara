<span class="comp_tut kwa">use</span> Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Compara<span class="comp_tut opt">::</span>DBSQL<span class="comp_tut opt">::</span>DBAdaptor

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$host</span>   <span class="comp_tut opt">=</span> <span class="comp_tut str">'ensembldb.ensembl.org'</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$user</span>   <span class="comp_tut opt">=</span> <span class="comp_tut str">'anonymous'</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$port</span>   <span class="comp_tut opt">=</span> <span class="comp_tut num">5306</span><span class="comp_tut opt">;</span>
<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$dbname</span> <span class="comp_tut opt">=</span> <span class="comp_tut str">'ensembl_compara_51'</span><span class="comp_tut opt">;</span>

<span class="comp_tut kwc">my</span> <span class="comp_tut kwb">$comparadb</span><span class="comp_tut opt">=</span> new Bio<span class="comp_tut opt">::</span>EnsEMBL<span class="comp_tut opt">::</span>Compara<span class="comp_tut opt">::</span>DBSQL<span class="comp_tut opt">::</span>DBAdaptor<span class="comp_tut opt">(</span>
    <span class="comp_tut opt">-</span>host   <span class="comp_tut opt">=&gt;</span> <span class="comp_tut kwb">$host</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>port   <span class="comp_tut opt">=&gt;</span> <span class="comp_tut kwb">$port</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>user   <span class="comp_tut opt">=&gt;</span> <span class="comp_tut kwb">$user</span><span class="comp_tut opt">,</span>
    <span class="comp_tut opt">-</span>dbname <span class="comp_tut opt">=&gt;</span> <span class="comp_tut kwb">$dbname</span><span class="comp_tut opt">,</span>
<span class="comp_tut opt">);</span>
