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
<table style="width: 50%; margin: 0 25%;">
<tbody>
  <tr>
    <th>Species</th><th>Data size (Gb)</th>
  </tr>
);
foreach ( sort keys %X ) {
  printf qq(  <tr>
    <td>%s</td><td style="text-align: right;">%0.1f</td>
  </tr>
),
	$_, $X{$_}/1024/1024;
}
print qq(  <tr>
    <th>Multi-species</th><th>&nbsp;</th>
  </tr>
);
foreach ( sort keys %Y ) {
  printf qq(  <tr>
    <td>%s</td><td style="text-align: right;">%0.1f</td>
  </tr>
),
	$_, $Y{$_}/1024/1024;
}
printf qq(  <tr>
    <th>Total</th><th style="text-align: right;">%0.1f</th>
  </tr>
</tbody>
</table>
), $T/1024/1024;
__DATA__
5200900 aedes_aegypti_core_42_1a
2299168 anopheles_gambiae_core_42_3e
176194  anopheles_gambiae_otherfeatures_42_3e
403322  anopheles_gambiae_variation_42_3e
5532769 bos_taurus_core_42_2e
391994  bos_taurus_otherfeatures_42_2e
813824  caenorhabditis_elegans_core_42_160
9433816 canis_familiaris_core_42_2
257800  canis_familiaris_otherfeatures_42_2
1742091 canis_familiaris_variation_42_2
1989134 ciona_intestinalis_core_42_2d
354199  ciona_intestinalis_otherfeatures_42_2d
2525594 ciona_savignyi_core_42_2c
219329  ciona_savignyi_otherfeatures_42_2c
20471024        compara_mart_homology_42
2654043 compara_mart_multiple_ga_42
12141872        compara_mart_pairwise_ga_42
7642173 danio_rerio_core_42_6c
672269  danio_rerio_otherfeatures_42_6c
1895    danio_rerio_variation_42_6c
5444481 dasypus_novemcinctus_core_42_1b
950820  drosophila_melanogaster_core_42_43
150351  drosophila_melanogaster_otherfeatures_42_43
6059605 echinops_telfairi_core_42_1b
72157892        ensembl_compara_42
4821926 ensembl_go_42
20636376        ensembl_mart_42
4669078 gallus_gallus_core_42_2
348463  gallus_gallus_otherfeatures_42_2
1774824 gallus_gallus_variation_42_2
4596926 gasterosteus_aculeatus_core_42_1b
215715  gasterosteus_aculeatus_otherfeatures_42_1b
4457    healthchecks_42
478769  homo_sapiens_cdna_42_36d
10829685        homo_sapiens_core_42_36d
565062  homo_sapiens_funcgen_42_36d
3465599 homo_sapiens_otherfeatures_42_36d
14089467        homo_sapiens_variation_42_36d
582056  homo_sapiens_vega_42_36d
6164531 loxodonta_africana_core_42_1b
6462112 macaca_mulatta_core_42_10b
214525  macaca_mulatta_otherfeatures_42_10b
9475334 monodelphis_domestica_core_42_3b
417847  mus_musculus_cdna_42_36c
9724656 mus_musculus_core_42_36c
785155  mus_musculus_funcgen_42_36c
1966016 mus_musculus_otherfeatures_42_36c
18287387        mus_musculus_variation_42_36c
264912  mus_musculus_vega_42_36c
5888172 ornithorhynchus_anatinus_core_42_1
122905  ornithorhynchus_anatinus_otherfeatures_42_1
6265856 oryctolagus_cuniculus_core_42_1b
4000416 oryzias_latipes_core_42_1a
185386  oryzias_latipes_otherfeatures_42_1a
7094721 pan_troglodytes_core_42_21a
491526  pan_troglodytes_otherfeatures_42_21a
819964  pan_troglodytes_variation_42_21a
7280154 rattus_norvegicus_core_42_34l
400967  rattus_norvegicus_otherfeatures_42_34l
961586  rattus_norvegicus_variation_42_34l
430035  saccharomyces_cerevisiae_core_42_1e
49480928        sequence_mart_42
26353976        snp_mart_42
6186520 takifugu_rubripes_core_42_4d
18229   takifugu_rubripes_otherfeatures_42_4d
3509373 tetraodon_nigroviridis_core_42_1h
431760  tetraodon_nigroviridis_variation_42_1h
693280  vega_mart_42
5858603 xenopus_tropicalis_core_42_41c
427395  xenopus_tropicalis_otherfeatures_42_41c

