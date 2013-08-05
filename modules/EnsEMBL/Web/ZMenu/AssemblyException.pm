# $Id$

package EnsEMBL::Web::ZMenu::AssemblyException;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $dbID  = $hub->param('dbID');
  my $range = $hub->param('range');
  my $i     = 0;
  my @features;
  
  if (defined $dbID) {
    ## individual feature with zmenu
    @features = ($hub->get_adaptor('get_AssemblyExceptionFeatureAdaptor')->fetch_by_dbID($dbID));
  } elsif ($range) {
    ## Only showing one, but need zmenu info for all of the same type in the range
    my $type     = $hub->param('target_type');
       @features = grep $_->type eq $type, @{$hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('toplevel', split /[:-]/, $range)->get_all_AssemblyExceptionFeatures};
  }
  
  $self->{'feature_count'} = scalar @features;
  $self->feature_content($_, $i++) for @features;
}

sub feature_content {
  my ($self, $f, $i) = @_;
  my $hub = $self->hub;
  my $r   = $hub->param('feature') || sprintf '%s:%s-%s', map $f->alternate_slice->$_, qw(seq_region_name start end);
  my ($chr, $start, $end) = split /[:-]/, $r;
  
  my $species_defs  = $hub->species_defs;
  my $species       = $hub->species;
  my $type          = $hub->param('target_type'); # code for patch regions
  my $target        = $hub->param('target');      # code for patch regions - compare patch with reference
  my $threshold     = 1000100 * ($species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $this_assembly = $species_defs->ASSEMBLY_NAME;
  my $bgcolor       = $i % 2 ? 'bg2' : 'bg1';
  my $action        = $hub->action || 'View';
     $action        = 'Overview' if $end - $start + 1 > $threshold && $action eq 'View'; # go to Overview if region too large for View
  my $url           = $hub->url({ type => 'Location', action => $action, r => $r });
  
  if ($type =~ /^patch/i) {
    my $slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('toplevel', $chr, $start, $end);
    my $csa   = $hub->get_adaptor('get_CoordSystemAdaptor');
    my @synonyms;
    
    foreach my $name (qw(supercontig scaffold)) { # where patches are
      next unless $csa->fetch_by_name($name, $slice->coord_system->version);
      push @synonyms, map @{$_->to_Slice->get_all_synonyms}, @{$slice->project($name, $slice->coord_system->version) || []};
    }
    
    $self->add_entry({ label => sprintf('Synonyms: %s', join ', ', map $_->name, @synonyms), class => $bgcolor }) if scalar @synonyms; 
  }
  
  $self->caption($self->{'feature_count'} > 1 ? 'Assembly exceptions' : $r);
  $self->add_entry({ label => $r, link => $url, class => $bgcolor });
  
  if ($target) {
    $self->add_entry({
      class => $bgcolor,
      label => 'Compare with ' . (grep($chr eq $_, @{$species_defs->ENSEMBL_CHROMOSOMES}) ? $type =~ /hap/i ? 'haplotype' : 'patch' : 'reference'),
      link  => $hub->url({
        action   => 'Multi',
        function => undef,
        r        => $r,
        s1       => "$species--$target" 
      }),
    });
  }
}

1;
