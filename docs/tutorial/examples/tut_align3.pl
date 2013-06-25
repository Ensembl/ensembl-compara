my $query_species = 'human';
my $seq_region = '14';
my $seq_region_start = 75000000;
my $seq_region_end   = 75010000;

# Getting the Slice adaptor:
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $query_species, 'core', 'Slice');

# Fetching a Slice object:
my $query_slice = $slice_adaptor->fetch_by_region(
    'toplevel',
    $seq_region,
    $seq_region_start,
    $seq_region_end);

# Fetching all the GenomicAlignBlock corresponding to this Slice:
my $genomic_align_blocks =
    $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $human_mouse_blastz_net_mlss,
      $query_slice);
