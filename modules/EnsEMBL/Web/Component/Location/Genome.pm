# $Id$

package EnsEMBL::Web::Component::Location::Genome;

### Module to replace Karyoview

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my $chromosomes  = $species_defs->ENSEMBL_CHROMOSOMES || [];

  my ($html, $table, $user_pointers, $usertable, $features, $has_features, @all_features);
 
  if (my $id = $hub->param('id') || $hub->referer->{'ENSEMBL_TYPE'} eq 'LRG') { ## "FeatureView"
    $features = $self->builder->create_objects('Feature', 'lazy');
    $features = $features ? $features->convert_to_drawing_parameters : {};
    $table    = $self->feature_tables($features) if keys %$features;
  } 

  while (my ($type, $feature_set) = each (%$features)) {
    if ($feature_set && @$feature_set) {
      $has_features = 1;
      push @all_features, @{$feature_set->[0]};
    }
  }

  if (scalar @$chromosomes && $species_defs->MAX_CHR_LENGTH) {
    ## Now check if we have any features mapped to chromosomes
    my $draw_karyotype = $has_features ? 0 : 1;
    my $not_drawn;
    my %chromosome = map { $_ => 1 } @$chromosomes;
   
    foreach (@all_features) {
      if (ref($_) eq 'HASH' && $chromosome{$_->{'region'}}) {
        $draw_karyotype = 1;
      } else {
        $not_drawn++;
      }
    }

    if ($draw_karyotype) {
      my $image    = $self->new_karyotype_image;
      my $config   = $hub->get_imageconfig('Vkaryotype'); ## Form with hidden elements for click-through
      my $pointers = [];

      ## Deal with pointer colours
      my %used_colour;
      my %pointer_default = (
        DnaAlignFeature     => [ 'red', 'rharrow' ],
        ProteinAlignFeature => [ 'red', 'rharrow' ],
        RegulatoryFactor    => [ 'red', 'rharrow' ],
        ProbeFeature        => [ 'red', 'rharrow' ],
        Xref                => [ 'red', 'rharrow' ],
        Gene                => [ 'blue','lharrow' ],
        Domain              => [ 'blue','lharrow' ], 
      );
      
      ## Do internal Ensembl data
      if ($has_features) { ## "FeatureView"
        my $text      = 'Locations of ';
        my $data_type = $hub->param('ftype');
        my %names     = map { $_ => lc($_) . 's' } keys %$features;
        my @A         = keys %names;
        my $feature_names;
        
        if (@A == 1 && $A[0] eq $data_type) {
          $text .= $data_type;
        } else {
          if (scalar keys %names == 2) {
            $feature_names = join ' and ', sort values %names;  
          } else {
            $feature_names = join ', ', sort values %names;  
          }
          
          $text .= "$feature_names associated with $data_type";

          my @ids = $hub->param('id');
          
          if (@ids) {
            if (@ids > 1) {
              $text .= 's ' . join ', ', @ids;
            } else {
              $text .= ' ' . $ids[0];
            }
          }
        
          if ($hub->param('ftype') eq 'Phenotype'){
            my $phenotype_name = encode_entities($hub->param('phenotype_name') || $hub->param('id'));
            $text = "Location of variants associated with phenotype $phenotype_name:";        
          }
        }        
 
        $used_colour{$data_type}++;        
        $html = "<h2>$text</h2>" unless $names{'LRG'};        
                
        $image->image_name = "feature-$species";
        $image->imagemap   = 'yes';

        while (my ($feat_type, $set) = each (%$features)) {           
          my $defaults    = $pointer_default{$set->[2]};
          my $pointer_ref = $image->add_pointers($hub, {
            config_name  => 'Vkaryotype',
            features     => $set->[0],
            feature_type => $feat_type,
            color        => $hub->param('colour') || $defaults->[0],
            style        => $hub->param('style')  || $defaults->[1],
          });
          
          push @$pointers, $pointer_ref;
        }
      }       
      
      ($user_pointers, $usertable) = $self->create_user_set($image, $pointers);  #adding pointers to enable key display for non-user track for now its only xref

      ## Add some settings, if there is any user data
      if (@$user_pointers) {
        push @$pointers, @$user_pointers; 
        $image->imagemap = 'no';
      }
      
      if (!@$pointers) { ## Ordinary "KaryoView"
        $image->image_name = "karyotype-$species";
        $image->imagemap   = 'no';
      }
  
      $image->set_button('drag', 'title' => 'Click on a chromosome');
      $image->caption  = 'Click on the image above to jump to a chromosome, or click and drag to select a region';
      $image->imagemap = 'yes';
      $image->karyotype($hub, $self->object, $pointers, 'Vkaryotype');

      $html .= $image->render;
      
      if ($hub->param('ftype') eq 'Phenotype') { # making colour scale for pointers
        $html .= '<h3>Colour Scale:</h3>';
        
        my @colour_scale = $config->colourmap->build_linear_gradient(30, '#0000FF', '#770088', '#BB0044', 'red'); # making an array of the colour scale to make the scale
        
        foreach my $colour (@colour_scale) {      
          $html .= qq{<div style="border-style:solid;border-width:2px;float:left;width:20px;height:20px;background:#$colour"></div>};
        }
        
        $html .= '
        <br /><div style="clear:both"></div><span style="font-size:12px">1.0<div style="display: inline;  margin-left: 100px;"></div>3.0<div style="display: inline; margin-left: 55px;"></div>4.0<div style="display: inline;  margin-left: 60px;"></div>5.0<div style="display: inline; margin-left: 100px;"></div>7.0<div style="display: inline;  margin-left: 130px;"></div>9.0<div style="display: inline; margin-left: 140px;"></div>&gt;10.0</span><br />(Least Significant P Value) <div style="display: inline; margin-left: 420px;"></div> (Most Significant P Value)<br /><br />';
      }
    }
    
    if ($not_drawn) {
      my $plural  = $not_drawn > 1 ? 's' : '';
      my $message = $draw_karyotype ? 'therefore have not been drawn' : 'therefore the karyotype has not been drawn';
      $not_drawn  = 'These' if $not_drawn == @all_features;
      
      $html .= $self->_info('Undrawn features', "<p>$not_drawn feature$plural do not map to chromosomal coordinates and $message.</p>");
    }
  } else {
    $html .= $self->_info('Unassembled genome', '<p>This genome has yet to be assembled into chromosomes</p>');
  }

  if ($table || $usertable) {
    $html .= $table if $table;
    $html .= '<h3 style="margin-bottom:-5px">Key to tracks</h3>' . $usertable->render if $usertable;
  } else {
    $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/stats_$species.html");
  }
  
  return $html;
}

sub feature_tables {
  my $self         = shift;
  my $feature_dets = shift;
  my $hub          = $self->hub;
  my $data_type    = $hub->param('ftype');  
  my $html;
  my @tables;  
 
  while (my ($feat_type, $feature_set) = each (%$feature_dets)) {
    my $features      = $feature_set->[0];
    my $extra_columns = $feature_set->[1];
    
    # could show only gene links for xrefs, but probably not what is wanted:
    # next SET if ($feat_type eq 'Gene' && $data_type =~ /Xref/);
   
    my $data_type = $feat_type eq 'Gene' ? 'Gene Information:'
      : $feat_type eq 'Transcript' ? 'Transcript Information:'
      : 'Feature Information:';

    if ($feat_type eq 'Domain'){
      my $domain_id     = $hub->param('id');
      my $feature_count = scalar @$features;
      $data_type        = "Domain $domain_id maps to $feature_count Genes. The gene Information is shown below:";
    }

    my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { margin => '1em 0px' });
    
    if ($feat_type =~ /Gene|Transcript|Domain/) {
      $table->add_columns({ key => 'names',   title => 'Ensembl ID',               width => '25%',   align => 'left' });
      $table->add_columns({ key => 'loc',     title => 'Genomic location(strand)', width => '170px', align => 'left' });    
      $table->add_columns({ key => 'extname', title => 'External names',           width => '25%',   align => 'left' });
    } elsif ($feat_type =~ /Variation/i) {
      $table->add_columns({ key => 'loc',    title => 'Genomic location(strand)', width => '170px', align => 'left' });    
      $table->add_columns({ key => 'names',  title => 'Name(s)',                  width => '100px', align => 'left' });
    } elsif ($feat_type eq 'LRG') {
      $table->add_columns({ key => 'lrg',    title => 'Name',                     width => '15%', align => 'left' });
      $table->add_columns({ key => 'loc',    title => 'Genomic location(strand)', width => '15%', align => 'left' });
      $table->add_columns({ key => 'length', title => 'Genomic length',           width => '10%', align => 'left' });
    } else {	    
      $table->add_columns({ key => 'loc',    title => 'Genomic location(strand)', width => '15%', align => 'left' });
      $table->add_columns({ key => 'length', title => 'Genomic length',           width => '10%', align => 'left' });
      $table->add_columns({ key => 'names',  title => 'Name(s)',                  width => '25%', align => 'left' });
    }
        
    my $c = 1;
    $table->add_columns({ key => 'extra_' . $c++, title => $_, width => $feat_type =~ /Variation/i ? '300px' : '10%', align => 'left' }) for @{$extra_columns||[]};
        
    my @data;
    
    if ($feat_type eq 'LRG') {
      @data = sort { $a->{'lrg_number'} <=> $b->{'lrg_number'} } @$features;
    } else {
      @data = 
        map  { $_->[0] }
        sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
        map  { [ $_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20, $_->{'region'}, $_->{'start'} ] }
        @$features;
    }

    foreach my $row (@data) {
      my $contig_link = 'Unmapped';
      my $names       = '';
      my $data_row;
     
      if ($row->{'region'}) {
        $contig_link = sprintf(
          '<a href="%s">%s:%d-%d(%d)</a>',
          $hub->url({
            action  => 'View',
            r       => "$row->{'region'}:$row->{'start'}-$row->{'end'}",
            h       => $row->{'label'},
            __clear => 1
          }),
          $row->{'region'}, $row->{'start'}, $row->{'end'},
          $row->{'strand'}
        );

        if ($feat_type =~ /Gene|Transcript|Domain/ && $row->{'label'}) {
          $feat_type = 'Gene' if $feat_type eq 'Domain';
          my $param  = $feat_type eq 'Gene' ? 'g' : 't';
          
          $names = sprintf(
            '<a href="%s">%s</a>',
            $hub->url({
              type    => $feat_type,
              action  => 'Summary',
              $param  => $row->{'label'},
              r       => "$row->{'region'}:$row->{'start'}-$row->{'end'}",
              __clear => 1
            }),
            $row->{'label'}
          );
          
          $data_row = { extname => $row->{'extname'}, names => $names, loc => $contig_link };
        } else {
          if ($feat_type !~ /align|RegulatoryFactor|ProbeFeature/i && $row->{'label'}) {
            $names = sprintf(
              '<a href="%s">%s</a>',
              $hub->url({
                type    => 'Gene',
                action  => 'Summary',
                r       => "$row->{'region'}:$row->{'start'}-$row->{'end'}",
                g       => $row->{'label'},
                __clear => 1
              }),
              $row->{'label'}
            );            
          }
          
          if ($feat_type =~ /Variation/i && $row->{'label'}) {
            $contig_link = sprintf(
              '<a href="%s">%s:%s-%s(%s)</a>',
              $hub->url({
                action           => 'View',
                r                => "$row->{'region'}:$row->{'start'}-$row->{'end'}",
                v                => $row->{'label'},
                contigviewbottom => $row->{'somatic'} ? 'somatic_mutation_COSMIC=normal' : 'variation_feature_variation=normal',
                __clear          => 1
              }),
              $row->{'region'}, $row->{'start'}, $row->{'end'}, $row->{'strand'}
            );
            
            $names = sprintf(
              '<a href="%s">%s</a>',
              $hub->url({
                type    => 'Variation',
                action  => 'Phenotype',
                v       => $row->{'label'},
                __clear => 1
              }),
              $row->{'label'}
            );
          } else {
            $names  = $row->{'label'} if $row->{'label'};
          }
          
          $data_row = { loc => $contig_link, length => $row->{'length'}, names => $names };
        }
      }
      
      if ($feat_type eq 'LRG') {
        $data_row->{'lrg'} = sprintf(
          '<a href="%s/LRG/Summary?lrg=%s">%s</a>',
          $hub->url({
            type    => 'LRG',
            action  => 'Summary',
            lrg     => $row->{'lrg_name'},
            __clear => 1
          }),
          $row->{'lrg_name'}
        );
      } 
      
      my $c = 1;
      $data_row->{'extra_' . $c++} = $_ for @{$row->{'extra'}||[]};
      
      $c = 0;
      $data_row->{'initial' . $c++} = $_ for @{$row->{'initial'}||[]};
      
      $table->add_row($data_row);
    }
    
    if (@data) {
      $html .= qq(<strong>$data_type</strong>);
      $html .= $table->render;
    }
  }
  
  $html ||= sprintf '<br /><br />No mapping of %s found<br /><br />', $hub->param('id') || 'unknown feature';
  
  return $html;
}

1;
