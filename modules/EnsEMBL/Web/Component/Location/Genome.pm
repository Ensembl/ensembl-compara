#$Id$
package EnsEMBL::Web::Component::Location::Genome;

### Module to replace Karyoview

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Apache::SendDecPage;
use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self    = shift;
  my $model   = $self->model;
  my $hub     = $self->hub;
  my $species = $hub->species;

  my ($html, $table, $usertable, $features, $has_features, @all_features);
 
  if (my $id = $hub->param('id') || $hub->parent->{'ENSEMBL_TYPE'} eq 'LRG') { ## "FeatureView"
    $features = $model->create_objects('Feature', 'lazy')->convert_to_drawing_parameters;
    
    my @A = keys %$features;
    if (keys %$features) { $table = $self->feature_tables($features); }
  } 

  while (my ($type, $feature_set) = each (%$features)) {
    if ($feature_set && @$feature_set) {
      $has_features = 1;
      push @all_features, @{$feature_set->[0]};
    }
  }

  if ($hub->species_defs->ENSEMBL_CHROMOSOMES && scalar(@{$hub->species_defs->ENSEMBL_CHROMOSOMES}) && $hub->species_defs->MAX_CHR_LENGTH) {
    ## Now check if we have any features mapped to chromosomes
    my $draw_karyotype = $has_features ? 0 : 1;
    my $not_drawn;
    my %chromosome = map { $_ => 1 } @{$hub->species_defs->ENSEMBL_CHROMOSOMES};
   
    foreach (@all_features) {
      if (ref($_) eq 'HASH' && $chromosome{$_->{'region'}}) {
        $draw_karyotype = 1;
      } else {
        $not_drawn++;
      }
    }

    if ($draw_karyotype) {
      my $image    = $self->new_karyotype_image;
      my $pointers = [];

      ## Form with hidden elements for click-through
      my $config = $hub->get_imageconfig('Vkaryotype');

      ## Deal with pointer colours
      my %used_colour;
      my %pointer_default = (
        'DnaAlignFeature'     => ['red', 'rharrow'],
        'ProteinAlignFeature' => ['red', 'rharrow'],
        'RegulatoryFactor'    => ['red', 'rharrow'],
        'ProbeFeature'        => ['red', 'rharrow'],
        'XRef'                => ['red', 'rharrow'],
        'Gene'                => ['blue','lharrow'],
        'Domain'              => ['blue','lharrow'], 
      );

      ## Do internal Ensembl data
      if ($has_features) { ## "FeatureView"
        my $text = 'Locations of ';
        my $data_type = $hub->param('ftype');
        my $feature_names;
        my %names = map {$_ => lc($_).'s'} keys %$features;
        my @A = keys %names;
        if (@A == 1 && $A[0] eq $data_type) {
          $text .= $data_type;
        }
        else {
          if (scalar keys %names == 2) {
            $feature_names = join(' and ', sort values %names);  
          }
          else {
            $feature_names = join(', ', sort values %names);  
          }
          $text .= "$feature_names associated with $data_type";

          my @ids = ($hub->param('id'));
          if (@ids) {
            if (@ids > 1) {
              $text .= 's '.join(', ', @ids);
            }
            else {
              $text .= ' '.$ids[0];
            }
          }
        
          if ($hub->param('ftype') eq 'Phenotype'){
            my $phenotype_name = $hub->param('phenotype_name') || $hub->param('id');
            $text = "Location of variants associated with phenotype $phenotype_name:";        
          }
        }        
 
        $used_colour{$data_type}++;        
        $html = qq(<h2>$text</h2>) unless $names{'LRG'};        
                
        $image->image_name = "feature-$species";
        $image->imagemap = 'yes';

        while (my ($feat_type, $set) = each (%$features)) {           
          my $defaults = $pointer_default{$set->[2]};
          my $pointer_ref = $image->add_pointers($hub, {
            'config_name'   => 'Vkaryotype',
            'features'      => $set->[0],
            'feature_type'  => $feat_type,
            'color'         => $hub->param('colour') || $defaults->[0],
            'style'         => $hub->param('style') || $defaults->[1],
          });
          
          push(@$pointers, $pointer_ref);
        }
      }       
      my $colours = $self->colour_array;
      my $ok_colours = [];
      
      ## Remove any colours being used by features from the highlight colour array
      foreach my $colour (@$colours) {
        next if $used_colour{$colour};
        push @$ok_colours, $colour;
      }
      my $user_pointers;
      ($user_pointers, $usertable) = $self->create_user_set($image, $ok_colours);

      ## Add some settings, if there is any user data
      if( @$user_pointers ) {
        push @$pointers, @$user_pointers; 
        $image->imagemap = 'no';
      } 
      if (!@$pointers) { ## Ordinary "KaryoView"
        $image->image_name = "karyotype-$species";
        $image->imagemap = 'no';
      }
  
      $image->set_button('drag', 'title' => 'Click on a chromosome' );
      $image->caption = 'Click on the image above to jump to a chromosome, or click and drag to select a region';
      $image->imagemap = 'yes';
      $image->karyotype( $self->model, $pointers, 'Vkaryotype' );

      $html .= $image->render;      
      if($hub->param('ftype') eq 'Phenotype') {   #making colour scale for pointers
        $html .= '<h3>Colour Scale:</h3>';
        # making an array of the colour scale to make the scale
        my @colour_scale = $config->colourmap->build_linear_gradient(30, '#0000FF', '#770088', '#BB0044', 'red');  

        foreach my $colour (@colour_scale) {      
          $html .= qq{<div style='border-style:solid;border-width:2px;float:left;width:20px;height:20px;background:#$colour'></div>};
        }
        $html .= '<br /><div style="clear:both"></div><span style="font-size:12px">1.0<div style="display: inline;  margin-left: 100px;"></div>3.0<div style="display: inline;  margin-left: 55px;"></div>4.0<div style="display: inline;  margin-left: 60px;"></div>5.0<div style="display: inline;  margin-left: 100px;"></div>7.0<div style="display: inline;  margin-left: 130px;"></div>9.0<div style="display: inline;  margin-left: 140px;"></div>>10.0</span><br />(Least Significant P Value) <div style="display: inline;  margin-left: 420px;"></div> (Most Significant P Value)<br /><br />';
      }
    }
    
    if ($not_drawn) {
      my $plural = $not_drawn > 1 ? 's' : '';
      $not_drawn = 'These' if $not_drawn == @all_features;
      my $message = $draw_karyotype ? 'therefore have not been drawn' : 'therefore the karyotype has not been drawn';
      $html .= $self->_info( 'Undrawn features', "<p>$not_drawn feature$plural do not map to chromosomal coordinates and $message.</p>" );
    }
  } else {
    $html .= $self->_info( 'Unassembled genome', '<p>This genome has yet to be assembled into chromosomes</p>' );
  }

  if ($table || $usertable) {
    $html .= $table if $table;
    if ($usertable) {
      $html .= '<h3>Key to user data tracks</h3>'.$usertable->render;
    };
  } else {
    my $file = '/ssi/species/stats_'.$hub->species.'.html';
    $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file);
    
  }
  return $html;
}

sub feature_tables {
  my $self = shift;
  my $feature_dets = shift;
  my $hub = $self->model->hub;
  my $data_type = $hub->param('ftype');  
  my $html;
  my @tables;  
 
  while (my($feat_type, $feature_set) = each (%$feature_dets)) {
    my $features = $feature_set->[0];
    my $extra_columns = $feature_set->[1];

    # could show only gene links for xrefs, but probably not what is wanted:
    # next SET if ($feat_type eq 'Gene' && $data_type =~ /Xref/);
    
    my $data_type = ($feat_type eq 'Gene') ? 'Gene Information:'
      : ($feat_type eq 'Transcript') ? 'Transcript Information:'
      : 'Feature Information:';

    if ($feat_type eq 'Domain'){
      my $domain_id = $hub->param('id');
      my $feature_count = scalar @$features;
      $data_type = "Domain $domain_id maps to $feature_count Genes. The gene Information is shown below:";
    }

    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
    
    if ($feat_type =~ /Gene|Transcript|Domain/) {
      $table->add_columns({'key'=>'names',  'title'=>'Ensembl ID',      'width'=>'25%','align'=>'left' });
      $table->add_columns({'key'=>'extname','title'=>'External names',  'width'=>'25%','align'=>'left' });
    } 
    elsif ($feat_type =~ /Variation/i) {
      $table->add_columns({'key'=>'loc',   'title'=>'Genomic location(strand)','width'=>'170px','align'=>'left' });    
      $table->add_columns({'key'=>'names', 'title'=>'Name(s)','width'=>'100px','align'=>'left' });
    } 
    elsif ($feat_type eq 'LRG') {
      $table->add_columns({'key'=>'lrg',   'title'=>'Name',  'width' =>'15%','align'=>'left' });
      $table->add_columns({'key'=>'loc',   'title'=>'Genomic location(strand)','width' =>'15%','align'=>'left' });
      $table->add_columns({'key'=>'length','title'=>'Genomic length',  'width'=>'10%','align'=>'left' });
    }
    else {	    
      $table->add_columns({'key'=>'loc',   'title'=>'Genomic location(strand)','width' =>'15%','align'=>'left' });
      $table->add_columns({'key'=>'length','title'=>'Genomic length',  'width'=>'10%','align'=>'left' });
      $table->add_columns({'key'=>'names', 'title'=>'Name(s)',        'width'=>'25%','align'=>'left' });
    }
        
    my $c = 1;
    
    for( @{$extra_columns||[]} ) {
      my $width  =  ($feat_type =~ /Variation/i) ? '300px' : '10%';
      $table->add_columns({'key'=>"extra_$c",'title'=>$_,'width'=>$width,'align'=>'left' });      
      $c++;
    }
        
    my @data;
    if ($feat_type eq 'LRG') {
      @data = sort {$a->{'lrg_number'} <=> $b->{'lrg_number'}} @$features;
    }
    else {
      @data = map { $_->[0] }
        sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
        map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20, $_->{'region'}, $_->{'start'}] }
        @$features;
    }

    foreach my $row (@data) {
      my $contig_link = 'Unmapped';
      my $names = '';
      my $data_row;
     
      if ($row->{'region'}) {
        $contig_link = sprintf(
          '<a href="%s/Location/View?r=%s:%d-%d;h=%s">%s:%d-%d(%d)</a>',
          $hub->species_defs->species_path,
          $row->{'region'}, $row->{'start'}, $row->{'end'}, $row->{'label'},          
          $row->{'region'}, $row->{'start'}, $row->{'end'},
          $row->{'strand'}
        );

        if ($feat_type =~ /Gene|Transcript|Domain/ && $row->{'label'}) {
          $feat_type = 'Gene' if $feat_type eq 'Domain';
          my $t = $feat_type eq 'Gene' ? 'g' : 't';
          
          $names = sprintf(
            '<a href="%s/%s/Summary?%s=%s;r=%s:%d-%d">%s</a>',
            $hub->species_defs->species_path, $feat_type, $t, $row->{'label'},
            $row->{'region'}, $row->{'start'}, $row->{'end'},
            $row->{'label'}
          );
         
          my $extname = $row->{'extname'};
          my $desc =  $row->{'extra'}[0];
          $data_row = { 'extname' => $extname, 'names' => $names };
        } else {
          if ($feat_type !~ /align|RegulatoryFactor|ProbeFeature/i && $row->{'label'}) {
            $names = sprintf(
              '<a href="%s/Gene/Summary?g=%s;r=%s:%d-%d">%s</a>',
              $hub->species_defs->species_path, $row->{'label'},
              $row->{'region'}, $row->{'start'}, $row->{'end'},
              $row->{'label'}
            );            
          } 
          if ($feat_type =~ /Variation/i && $row->{'label'}) {            
            my $species_path = $hub->species_defs->species_path;
            
            #setting phenotype variation track on 
            my $track = qq{contigviewbottom=variation_set_Phenotype-associated variations=normal};
            $contig_link = qq{<a href="$species_path/Location/View?r=$row->{'region'}:$row->{'start'}-$row->{'end'};h=$row->{'label'};$track">$row->{'region'}:$row->{'start'}-$row->{'end'}($row->{'strand'})</a>};   #better way of doing a simple link for Genomic location
            $names = qq{<a href="$species_path/Variation/Phenotype?v=$row->{'label'}">$row->{'label'}</a>};   #better way of doing a simple link for Name(s)
          }
          else {
            $names  = $row->{'label'} if $row->{'label'};
          }
          
          my $length = $row->{'length'};
          $data_row = { 'loc'  => $contig_link, 'length' => $length, 'names' => $names };
        }
      }
      
      if ($feat_type eq 'LRG') {
        my $link = sprintf(
          '<a href="%s/LRG/Summary?lrg=%s">%s</a>',
          $hub->species_defs->species_path, $row->{'lrg_name'}, $row->{'lrg_name'}
        );
        $data_row->{'lrg'} = $link;
      } 
      
      my $c = 1;
      
      for( @{$row->{'extra'}||[]} ) {
        $data_row->{"extra_$c"} = $_;
        $c++;
      }
      
      $c = 0;
      
      for( @{$row->{'initial'}||[]} ) {
        $data_row->{"initial$c"} = $_;
        $c++;
      }
      
      $table->add_row($data_row);
    }
    
    if (@data) {
      $html .= qq(<strong>$data_type</strong>);
      $html .= $table->render;
    }
  }
  
  if (!$html) {
    my $id = $hub->param('id') || 'unknown feature';
    $html .= qq(<br /><br />No mapping of $id found<br /><br />);
  }
  
  return $html;
}

1;
