# $Id$

package EnsEMBL::Web::ZMenu::Location;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $dbID  = $hub->param('dbID');
  my @click = $self->click_location;
  my $i     = 0;
  my @features;
  
  if (defined $dbID) {
    ## individual feature with zmenu
    @features = ($hub->get_adaptor('get_AssemblyExceptionFeatureAdaptor')->fetch_by_dbID($dbID));
  } elsif (scalar @click) {
    ## Only showing one, but need zmenu info for all of the same type
    my $type     = $hub->param('target_type');
       @features = grep [ split ' ', $_->type ]->[0] eq $type, @{$hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('toplevel', @click)->get_all_AssemblyExceptionFeatures};
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
  my $alt_assembly  = $hub->param('assembly'); # code for alternative assembly
  my $alt_clone     = $hub->param('jump_loc'); # code for alternative clones
  my $class         = $hub->param('class');    # code for patch regions
  my $target        = $hub->param('target');   # code for patch regions - compare patch with reference
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
  } elsif ($class =~ /^patch/) {
    my $slice;
    
    if ($f) {
      $slice = $f->slice;
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
    
    $self->add_entry({ label => sprintf('Synonyms: %s', join ', ', map $_->name, @synonyms) }) if scalar @synonyms; 
    
    $link_title = $caption;
  }
  
  if ($self->{'feature_count'} > 1) {
    $self->caption('Assembly exceptions');
  } else {
    $self->caption($caption || $r);
  }
  
  $self->add_entry({ label => $link_title || $r, link => $url, class => $bgcolor });
  
  if ($target) {
    $self->add_entry({
      class => $bgcolor,
      label => 'Compare with ' . (grep($chr eq $_, @{$species_defs->ENSEMBL_CHROMOSOMES}) ? $hub->param('target_type') eq 'HAP' ? 'haplotype' : 'patch' : 'reference'),
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
