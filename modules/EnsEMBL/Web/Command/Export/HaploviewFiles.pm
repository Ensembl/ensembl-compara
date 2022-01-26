=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Command::Export::HaploviewFiles;

use strict;

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::TmpFile::Tar;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $hub    = $self->hub;
  my $url    = $hub->url({ action => 'LDFormats', function => $hub->function });
  my $params = { type => 'haploview', %{$self->make_files} };
  
  $self->ajax_redirect($url, $params);
}

sub make_files {
  my $self = shift;
  my $location = $self->object->get_location_object;
  
  my $gen_file   = EnsEMBL::Web::TmpFile::Text->new(extension => 'ped', prefix => 'export');
  my $locus_file = EnsEMBL::Web::TmpFile::Text->new(
    filename  => $gen_file->filename,
    extension => 'txt',
    prefix    => 'export'
  );
  
  my $slice_genotypes = $location->get_all_genotypes; # gets all genotypes in the Slice as a hash. where key is region_name-region_start
  
  my ($family, $locus, $genotype);
  my %sample_genotypes;
  my %samples;
  my @snps;  
  
  foreach my $vf (@{$location->get_variation_features}) {
    my ($genotypes, $sample_data) = $location->sample_genotypes($vf, $slice_genotypes);
    
    next unless %$genotypes;
    
    my $name = $vf->variation_name;
    my $start = $vf->start;
    
    $locus .= "$name $start\r\n";
    
    push (@snps, $name);
    
    map { $sample_genotypes{$_}->{$name} = $genotypes->{$_} } keys %$genotypes;
    map { $samples{$_} = $sample_data->{$_} } keys %$sample_data;
  }
  
  foreach my $sample (keys %sample_genotypes) {
    my $s      = $samples{$sample};
    my $output = join "\t", 'FAM' . $family++, $sample, $s->{'father'}, $s->{'mother'}, $s->{'gender'}, "0\t";
       $output =~ s/ /_/g;
    
    foreach (@snps) {
      my $snp = $sample_genotypes{$sample}->{$_} || '00';
      $snp =~ tr/ACGTN/12340/;
      
      $output .= join ' ', split //, $snp;
      $output .= "\t";
    }
    
    $genotype .= "$output\r\n";
  }
  
  print $gen_file ($genotype || 'No data available');
  print $locus_file ($locus || 'No data available');
  
  $gen_file->save;
  $locus_file->save;
  
  my $tar_file = EnsEMBL::Web::TmpFile::Tar->new(
    filename        => $gen_file->filename,
    prefix          => '',
    use_short_names => 1
  );
  
  $tar_file->add_file($gen_file);
  $tar_file->add_file($locus_file);
  $tar_file->save;
  
  return {
    gen_file   => uri_escape($gen_file->URL),
    locus_file => uri_escape($locus_file->URL),
    tar_file   => uri_escape($tar_file->URL)
  };
}

1;
