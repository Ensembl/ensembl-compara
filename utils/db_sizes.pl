while(<DATA>) {
  chomp;
  ($size,$_) = split;
    /health/             ? 1 
  : /_mart_/             ? ( $Y{'Mart'} += $size          )
  : /ensembl_([a-z]+)_/  ? ( $Y{ucfirst($1)}+= $size      )
  : /([a-z]+)_([a-z]+)_/ ? ( $X{ucfirst("$1 $2")} += $size)
  :                        0
  ;
    /health/             ? 1
  :                        ($T+=$size)
  ; 
}

print qq(
<table style="width: 50%; margin: 0 25%;"><tbody>
  <tr><th>Species</th>                    <th>Data size (Gb)</th>                   </tr>\n);
foreach ( sort keys %X ) {
  printf qq(  <tr><td>%-32.32s<td style="text-align: right;">%-11.11s</tr>\n),
	"$_</td>", sprintf( "%0.1f</td>",$X{$_}/1024/1024);
}
print qq(  <tr><th>Multi-species</th>              <th>&nbsp;</th>                           </tr>\n);
foreach ( sort keys %Y ) {
  printf qq(  <tr><td>%-32.32s<td style="text-align: right;">%-11.11s</tr>\n),
	"$_</td>", sprintf( "%0.1f</td>",$Y{$_}/1024/1024);
}
printf qq(  <tr><th>Total</th>                      <th style="text-align: right;">%-11.11s</tr>\n</tbody></table>\n),
        sprintf( "%0.1f</td>", $T/1024/1024);
__DATA__
7208860 aedes_aegypti_core_43_1a
2298960 anopheles_gambiae_core_43_3f
176552  anopheles_gambiae_otherfeatures_43_3f
386780  anopheles_gambiae_variation_43_3f
9167044 bos_taurus_core_43_3
1098256 bos_taurus_otherfeatures_43_3
868232  caenorhabditis_elegans_core_43_160a
9429332 canis_familiaris_core_43_2a
258220  canis_familiaris_otherfeatures_43_2a
1742132 canis_familiaris_variation_43_2a
3920224 cavia_porcellus_core_43_1
2083348 ciona_intestinalis_core_43_2e
354624  ciona_intestinalis_otherfeatures_43_2e
2524892 ciona_savignyi_core_43_2c
219676  ciona_savignyi_otherfeatures_43_2c
7666248 danio_rerio_core_43_6d
672624  danio_rerio_otherfeatures_43_6d
2076    danio_rerio_variation_43_6d
5431644 dasypus_novemcinctus_core_43_1b
948136  drosophila_melanogaster_core_43_43a
150784  drosophila_melanogaster_otherfeatures_43_43a
6046528 echinops_telfairi_core_43_1b
7689964 erinaceus_europaeus_core_43_1
5616996 felis_catus_core_43_1
4275688 gallus_gallus_core_43_2a
348780  gallus_gallus_otherfeatures_43_2a
1774924 gallus_gallus_variation_43_2a
4596156 gasterosteus_aculeatus_core_43_1b
216036  gasterosteus_aculeatus_otherfeatures_43_1b
480024  homo_sapiens_cdna_43_36e
9989192 homo_sapiens_core_43_36e
374256  homo_sapiens_funcgen_43_36e
3465960 homo_sapiens_otherfeatures_43_36e
15205668        homo_sapiens_variation_43_36e
582348  homo_sapiens_vega_43_36e
6151632 loxodonta_africana_core_43_1b
6453704 macaca_mulatta_core_43_10c
214888  macaca_mulatta_otherfeatures_43_10c
9439604 monodelphis_domestica_core_43_3c
426108  mus_musculus_cdna_43_36d
9559504 mus_musculus_core_43_36d
540536  mus_musculus_funcgen_43_36d
1966364 mus_musculus_otherfeatures_43_36d
18448712        mus_musculus_variation_43_36d
384760  mus_musculus_vega_43_36d
5774616 ornithorhynchus_anatinus_core_43_1a
141852  ornithorhynchus_anatinus_otherfeatures_43_1a
6254260 oryctolagus_cuniculus_core_43_1b
3973124 oryzias_latipes_core_43_1a
185744  oryzias_latipes_otherfeatures_43_1a
6771828 pan_troglodytes_core_43_21b
491880  pan_troglodytes_otherfeatures_43_21b
820124  pan_troglodytes_variation_43_21b
7015416 rattus_norvegicus_core_43_34m
401336  rattus_norvegicus_otherfeatures_43_34m
1022980 rattus_norvegicus_variation_43_34m
148344  saccharomyces_cerevisiae_core_43_1f
3976    saccharomyces_cerevisiae_otherfeatures_43_1f
6211476 takifugu_rubripes_core_43_4e
18656   takifugu_rubripes_otherfeatures_43_4e
3508588 tetraodon_nigroviridis_core_43_1h
428060  tetraodon_nigroviridis_variation_43_1h
6716104 tupaia_belangeri_core_43_1
5850696 xenopus_tropicalis_core_43_41d
427744  xenopus_tropicalis_otherfeatures_43_41d
87320788        ensembl_compara_43
4821964 ensembl_go_43
92185544        compara_mart_homology_43
3194064 compara_mart_multiple_ga_43
12935948        compara_mart_pairwise_ga_43
25798308        ensembl_mart_43
63607684        sequence_mart_43
26481036        snp_mart_43
1006008 vega_mart_43

