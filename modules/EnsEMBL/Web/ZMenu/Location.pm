# $Id$

package EnsEMBL::Web::ZMenu::Location;

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
  $self->feature_content($_, $i++) for $self->{'feature_count'} ? @features : $hub->param('r');
}

sub feature_content {
  my ($self, $f, $i) = @_;
  my $hub = $self->hub;
  my $r   = $hub->param('feature') || ref $f ? sprintf '%s:%s-%s', map $f->alternate_slice->$_, qw(seq_region_name start end) : $f;
  my ($chr, $start, $end) = split /[:-]/, $r;
  
  my $species_defs  = $hub->species_defs;
  my $species       = $hub->species;
  my $alt_assembly  = $hub->param('assembly');    # code for alternative assembly
  my $alt_clone     = $hub->param('jump_loc');    # code for alternative clones
  my $type          = $hub->param('target_type'); # code for patch regions
  my $target        = $hub->param('target');      # code for patch regions - compare patch with reference
  my $threshold     = 1000100 * ($species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $this_assembly = $species_defs->ASSEMBLY_NAME;
  my $bgcolor       = $i % 2 ? 'bg2' : 'bg1';
  my $action        = $hub->action || 'View';
     $action        = 'Overview' if $end - $start + 1 > $threshold && $action eq 'View'; # go to Overview if region too large for View
  my $url           = $hub->url({ type => 'Location', action => $action, r => $r });
  my ($caption, $link_title);
  
  if ($alt_assembly) {
    $caption = "$alt_assembly:$r";
    
    if ($this_assembly =~ /VEGA/) {
      $link_title = 'Jump to Ensembl';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $r;
    } elsif ($alt_assembly =~ /VEGA/) {
      $link_title = 'Jump to VEGA';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $r;
    } else {
      # TODO: put URL to the latest archive site showing the other assembly (from mapping_session table)
    }
    
    $self->add_entry({ label => "Assembly: $alt_assembly" });
  } elsif ($alt_clone) { 
    my $status = $hub->param('status');
    ($caption) = split ':', $alt_clone;
    
    if ($this_assembly =~ /VEGA/) {
      $link_title = 'Jump to Ensembl';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $alt_clone;
    } else {
      $link_title = 'Jump to Vega';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $alt_clone;
    }
    
    $status =~ s/_clone/ version/g;
    
    $self->add_entry({ label => "Status: $status" });
  } elsif ($type =~ /^patch/i) {
    my $slice;
    
    if ($f) {
      $slice = $f->alternate_slice;
    } else {
      my $adaptor = $hub->get_adaptor('get_SliceAdaptor');
         $slice   = $adaptor->fetch_by_region('toplevel', $chr, $start, $end);
    }
    
    my @synonyms;
    my $csa = $hub->get_adaptor('get_CoordSystemAdaptor');
    
    foreach my $name (qw(supercontig scaffold)) { # where patches are
      next unless $csa->fetch_by_name($name, $slice->coord_system->version);
      push @synonyms, map @{$_->to_Slice->get_all_synonyms}, @{$slice->project($name, $slice->coord_system->version) || []};
    }
    
    $self->add_entry({ label => sprintf('Synonyms: %s', join ', ', map $_->name, @synonyms), class => $bgcolor }) if scalar @synonyms; 
    
    $link_title = $caption;
  }
  
  if ($type && $self->{'feature_count'} > 1) {
    $self->caption('Assembly exceptions');
  } else {
    $self->caption($caption || $r);
  }
  
  $self->add_entry({ label => $link_title || $r, link => $url, class => $bgcolor });
  
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
