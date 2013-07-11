# $Id$

package EnsEMBL::Web::ZMenu::Location;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self  = shift;
  my $r     = $self->hub->param('r');
  my ($chr, $start, $end) = split ':|-', $r;

  my @features;
  if ($self->hub->param('depth') && $self->hub->param('depth') == 1) {
    ## Only showing one, but need zmenu info for all
    my $slice_adaptor = $self->hub->get_adaptor('get_SliceAdaptor');
    my $loc           = $self->hub->param('target') || $chr;
    my $click_slice   = $slice_adaptor->fetch_by_region('toplevel', $loc, $start, $end); 
    @features         = @{$click_slice->get_all_AssemblyExceptionFeatures||[]};
  }
  else {
    ## individual feature with zmenu
    my $adaptor = $self->hub->get_adaptor('get_AssemblyExceptionFeatureAdaptor');
    @features = ($adaptor->fetch_by_dbID($self->hub->param('dbID')));
  }

  $self->{'feature_count'} = scalar @features;

  my $i = 0;
  $self->feature_content($_, $i++) for @features;
}

sub feature_content {
  my ($self, $f, $i) = @_;
  my $hub            = $self->hub;
  my $species_defs   = $hub->species_defs;
  my $species        = $hub->species;

  my $alt_assembly   = $hub->param('assembly'); # code for alternative assembly
  my $alt_clone      = $hub->param('jump_loc'); # code for alternative clones
  my $class          = $hub->param('class');    # code for patch regions
  my $target         = $hub->param('target');   # code for patch regions - compare patch with reference
  my $threshold      = 1000100 * ($species_defs->ENSEMBL_GENOME_SIZE||1);
  my $this_assembly  = $species_defs->ASSEMBLY_NAME;
  my $bgcolor        = $i % 2 ? 'bg2' : 'bg1';
 
  my $depth = $hub->param('depth') || 0;
  my $chr   = $depth == 1 ? $f->alternate_slice->seq_region_name 
                          : $f->slice->seq_region_name;
  my $start = $f->alternate_slice->start;
  my $end   = $f->alternate_slice->end;
  my $r     = $chr.':'.$start.'-'.$end;

  my $action         = $hub->action || 'View';
     $action         = 'Overview' if $end - $start + 1 > $threshold && $action eq 'View'; # go to Overview if region too large for View
  my $url            = $hub->url({ type => 'Location', action => $action, r => $r });
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
  } elsif ($class && $class =~ /^patch/) {
    my $slice;
    if ($f) {
      $slice = $f->slice;
    }
    else {
      my $adaptor = $self->hub->get_adaptor('get_SliceAdaptor');
      $slice   = $adaptor->fetch_by_region('toplevel', $chr, $start, $end);
    }

    my @synonyms;
    my $csa = $self->hub->get_adaptor('get_CoordSystemAdaptor');
    foreach my $name (qw(supercontig scaffold)) { # where patches are
      next unless $csa->fetch_by_name($name,$slice->coord_system->version);
      my $projections=$slice->project($name,$slice->coord_system->version);
      next unless $projections;
      push @synonyms,
        (map { @{$_->to_Slice->get_all_synonyms} } @$projections);
    }
    my %synonyms = (map { $_->name => 1 } @synonyms);
    if(@synonyms) {
      $self->add_entry({ label => "Synonyms: ".join(", ",keys %synonyms) }); 
    }
    $link_title = $caption;
  }
  
  if ($self->{'feature_count'} > 1) {
    $self->caption('Assembly exceptions');
  }
  else {
    $self->caption($caption || $r);
  }
  $self->add_entry({ label => $link_title || $r, link => $url, class => $bgcolor });
  
  if ($target) {
    $self->add_entry({
      label => 'Compare with ' . (grep($chr eq $_, @{$species_defs->ENSEMBL_CHROMOSOMES}) ? $hub->param('target_type') eq 'HAP' ? 'haplotype' : 'patch' : 'reference'),
      link  => $hub->url({
        action   => 'Multi',
        function => undef,
        r        => $r,
        s1       => "$species--$target" 
      }),
      class => $bgcolor,
    });
  }
}

1;
