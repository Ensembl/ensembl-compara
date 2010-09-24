package EnsEMBL::Web::Tools::OntologyVisualisation;

use strict;
use warnings;
use URI::Escape;
use GraphViz;

use Bio::EnsEMBL::DBSQL::OntologyTermAdaptor;
no warnings "uninitialized";

sub new {
  my $class = shift;
  my $self;
  $self->{_ontology_term_adaptor}= shift;
  $self->{_img_base_dir}= shift;
  $self->{_img_base_url}= shift;
  $self->{_idurl}= shift;
  $self->{_image_background_colour}=_format_colour_code(shift,'transparent');
  $self->{_node_fill_colour}=_format_colour_code(shift,'transparent');
  $self->{_node_font_colour}=_format_colour_code(shift,'000000');
  $self->{_node_border_colour}=_format_colour_code(shift,'000000');
  $self->{_non_highlight_fill_colour}=_format_colour_code(shift,'transparent');
  $self->{_non_highlight_font_colour}=_format_colour_code(shift,'000000');
  $self->{_non_highlight_border_colour}=_format_colour_code(shift,'000000');
  $self->{_get_relation_type_colour}=shift;
  
  $self->{_existing_terms}=_init_hash(shift);
  $self->{_node_descriptions}=_init_hash(shift);
  $self->{_existing_edges}=_init_hash(shift);
  my @array=();
  $self->{_highlighted_term_accessions}=\@array;
  $self->{_non_highlighted_term_accessions}=\@array;  
  $self->{_clusters}={};

  if(defined($self->{_get_relation_type_colour}) && ref $self->{_get_relation_type_colour} ne "CODE"){
    $self->{_get_relation_type_colour}=_format_colour_code($self->{_get_relation_type_colour},'000000');
  }
  
  bless $self, $class;
  return $self;
}

sub existing_terms{
  my $self=shift;
  my $existing_terms= shift;
  $self->{_existing_terms} = $existing_terms if defined($existing_terms);
  return $self->{_existing_terms};
}

sub node_descriptions{
  my $self=shift;
  my $node_descriptions= shift;
  $self->{_node_descriptions} = $node_descriptions if defined($node_descriptions);
  return $self->{_node_descriptions};
}

sub existing_edges{
  my $self=shift;
  my $existing_edges= shift;
  $self->{_existing_edges} = $existing_edges if defined($existing_edges);
  return $self->{_existing_edges};
}

sub img_base_dir{
  my $self=shift;
  my $img_base_dir = shift;
  $self->{_img_base_dir}= $img_base_dir if defined($img_base_dir);
  return $self->{_img_base_dir};
}

sub img_base_url{
  my $self=shift;
  my $img_base_url = shift;
  $self->{_img_base_url}= $img_base_url if defined($img_base_url);
  return $self->{_img_base_url};
}

sub idurl{
  my $self=shift;
  my $idurl = shift;
  $self->{_idurl}= $idurl if defined($idurl);
  return $self->{_idurl};
}

sub image_background_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_image_background_colour}= $colour if defined($colour);
  return $self->{_image_background_colour};
}

sub node_fill_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_node_fill_colour}= $colour if defined($colour);
  return $self->{_node_fill_colour};
}

sub node_font_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_node_font_colour}= $colour if defined($colour);
  return $self->{_node_font_colour};
}

sub node_border_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_node_border_colour}= $colour if defined($colour);
  return $self->{_node_border_colour};
}

sub non_highlight_fill_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_non_highlight_fill_colour}= $colour if defined($colour);
  return $self->{_non_highlight_fill_colour};
}

sub non_highlight_font_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_non_highlight_font_colour}= $colour if defined($colour);
  return $self->{_non_highlight_font_colour};
}

sub non_highlight_border_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_non_highlight_border_colour}= $colour if defined($colour);
  return $self->{_non_highlight_border_colour};
}

sub highlighted_term_accessions{
  my $self=shift;
  my @highlighted_term_accessions = @_;
  $self->{_highlighted_term_accessions}=\@highlighted_term_accessions if (scalar(@highlighted_term_accessions)>0);
  return $self->{_highlighted_term_accessions};
}

sub non_highlighted_term_accessions{
  my $self=shift;
  my @non_highlighted_term_accessions = @_;
  $self->{_non_highlighted_term_accessions}=\@non_highlighted_term_accessions if (scalar(@non_highlighted_term_accessions)>0);
  return $self->{_non_highlighted_term_accessions};
}

sub ontology_term_adaptor{
  my $self=shift;
  my $ontology_term_adaptor = shift;
  $self->{_ontology_term_adaptor}= $ontology_term_adaptor if defined($ontology_term_adaptor);
  return $self->{_ontology_term_adaptor};
}

sub add_cluster_by_parent_accession{
  my $self=shift;
  my $new_cluster = shift;
  if(!$self->{_clusters}->{$new_cluster}){
    $self->{_clusters}->{$new_cluster}= GraphViz->new(nodesep=>0.5, ranksep=>2,layout => 'dot', ratio => 'compress', fontname=>"courier", bgcolor=>$self->image_background_colour, style=>'filled', landscape=>'true',
      node => {labeljust=>'r', margin=>'0.03,0', ratio => 'compress',shape => 'box', fontsize => '10pt', height=>'.2', fontname=>"courier",  fontnames=>'ps'});
  }
}

sub render{
  my $self=shift;
  my $ontology_term_adaptor = $self->ontology_term_adaptor;
  if (!defined($ontology_term_adaptor)){ die 'Bio::EnsEMBL::DBSQL::OntologyTermAdaptor ontology_term_adaptor not defined'};

  my $term = shift;
  
  for my $key ( @{$self->highlighted_term_accessions} ) {#add the nodes we retreived, and highlight them
    $self->_add_node($key, $self->node_border_colour,$self->node_fill_colour, $self->node_font_colour);
  }

  for my $key ( @{$self->non_highlighted_term_accessions} ) {#add the nodes we retreived, and highlight them
    $self->_add_node($key, $self->non_highlight_border_colour,$self->non_highlight_fill_colour, $self->non_highlight_font_colour);
  }

  my @all_terms =  @{$self->highlighted_term_accessions} ;
  push(@all_terms,@{$self->non_highlighted_term_accessions});
  
  for my $key ( @all_terms ) {#add all parents of the nodes we retreived
    my $term = $ontology_term_adaptor->fetch_by_accession($key);
    $self->_add_parents($term,$ontology_term_adaptor);
  }
  my $return_html='';
  my $images_html='';
  mkdir($self->img_base_dir);
  foreach(keys %{$self->{_clusters}}){
    my $cluster=$self->{_clusters}->{$_};
    my $file =  get_image_file_name();
	  open (MYFILE, '>>'.$self->img_base_dir.$file);
	  print MYFILE $cluster->as_png;
	  close (MYFILE);
    my $image_map = $cluster->as_cmapx;
    $image_map =~ s/title="([^"]*)" alt=""/ title="$self->{_node_descriptions}->{$1}" alt="$self->{_node_descriptions}->{$1}"/g;
	  $image_map =~ s/id="test" name="test"/id="$_" name="$_"/g;
	  $return_html.=$image_map;
    $images_html.=qq(<img style="float:none;" usemap="#).$_.qq(" src=").$self->img_base_url.$file.qq(" border="0">);
  }
  return $return_html.$images_html;
}

sub _add_node{
  my $self=shift;
  my $key=shift;
  my $border_colour=shift;
  my $fill_colour=shift;
  my $font_colour=shift; 
  
  my $ontology_term_adaptor = $self->ontology_term_adaptor;  
  #get term from go
  my $term = $ontology_term_adaptor->fetch_by_accession($key);
  my $cluster = $self->_get_cluster($term, $ontology_term_adaptor);
  
  #add the node if needed
  if(! $self->existing_terms->{$key}){
    $self->existing_terms->{$key}=1;
    $cluster->add_node($self->_format_node_name($term),URL=>$self->idurl.$term->accession, style=>'filled', color=>$border_colour,fillcolor=>$fill_colour, fontcolor=>$font_colour);
  }  
}

sub _add_parents{
  my $self=shift;
  my $term = shift;
  my $ontology_term_adaptor = shift;
  my $edge_colour_function = $self->{_get_relation_type_colour};

  my $parents = $ontology_term_adaptor->fetch_all_by_child_term($term);
  my $ancestors = $ontology_term_adaptor->_fetch_ancestor_chart($term);
  
  my $cluster = $self->_get_cluster($term, $ontology_term_adaptor);
  
  foreach (keys %$ancestors)  {
    my $ancestor_terms=$ancestors->{$_};
    foreach my $relation (keys %$ancestor_terms ){
      if(ref $ancestor_terms->{$relation} eq "ARRAY" ){#all parents are in 'name' =>[term,term] form
        foreach my $trm (@{$ancestor_terms->{$relation}}){
          foreach (@$parents){
            if($trm->accession eq $_->accession){#check that the parent is a direct parent
              if(! $self->existing_terms->{$trm->accession}){
                $self->existing_terms->{$trm->accession}=1;
                $cluster->add_node($self->_format_node_name($trm), URL=>$self->idurl.$trm->accession, style=>'filled', color=>$self->non_highlight_border_colour,
                fillcolor=>$self->non_highlight_fill_colour, fontcolor=>$self->non_highlight_font_colour);
              }
              if(! $self->existing_edges->{$term->accession.$trm->accession.$relation}){
                $self->existing_edges->{$term->accession.$trm->accession.$relation}=1;
                my $edge_colour;
                if(ref $edge_colour_function eq 'CODE'){
                  $edge_colour = _format_colour_code(&$edge_colour_function($relation),'000000');
                }elsif(1){
                  $edge_colour = _format_colour_code($edge_colour_function,'000000');
                }
                # $cluster->add_edge($self->_format_node_name($trm)=>$self->_format_node_name($term), label=>$relation, color=>$edge_colour, fontcolor=>
                # $edge_colour, dir=>'back'); #since we want a bottom-up tree, we add the link in the opposite direction and then set the directed option to backward.
                $cluster->add_edge($self->_format_node_name($trm)=>$self->_format_node_name($term), color=>$edge_colour, fontcolor=>
                $edge_colour, dir=>'back'); #since we want a bottom-up tree, we add the link in the opposite direction and then set the directed option to backward.                
              }
              $self->_add_parents($trm,$ontology_term_adaptor, $edge_colour_function);
            }
          }
        }
      }
    }
  }
}

sub _get_cluster{
  my $self=shift;
  my $term = shift;  
  my $ontology_term_adaptor = shift;
  
  my $all_parents = $ontology_term_adaptor->fetch_all_by_descendant_term($term);  
  #find out which cluster this belongs to
  my $cluster;
  if($self->{_clusters}->{$term->accession}){
    $cluster = $self->{_clusters}->{$term->accession};
  }else{
    foreach(@$all_parents){
      if($self->{_clusters}->{$_->accession}){	
        $cluster = $self->{_clusters}->{$_->accession};
      }
    }
  }
  if(!defined($cluster)){
    $self->add_cluster_by_parent_accession("\n");
    $cluster=$self->{_clusters}->{"\n"};
  }
  return $cluster;  
}

sub _format_node_name{
  my $self=shift;
  my $trm = shift;
  my $return_string = $trm->accession;
  $return_string=$trm->name;
  $return_string=~ s/_/ /g;
  $return_string=~s/ /\n/g;
  
  my $descr=$trm->name;
  $descr =~ s/_/ /g;
  my $key=$return_string;
  $key=~ s/\n/\\n/g;
  $key=~ s/-/&#45;/g;
  $self->node_descriptions->{$key}=$trm->accession." ".$descr;
  return $return_string;
}

sub get_image_file_name{
  return random_image_name().".png";
}

sub random_image_name {
  my $image_name;
  my $_rand;
  my $image_name_length=10;

  my @chars = ('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','X','0','1','2','3','4','5','6','7','8','9');

  srand;

  for (my $i=0; $i <= $image_name_length ;$i++) {
      $_rand = int(rand 62);
      $image_name .= $chars[$_rand];
  }
  return $image_name;
}

sub _format_colour_code{
  my $colour_code=shift;
  my $default = shift;
  if(defined($colour_code)){
    $colour_code='#'.$colour_code if ($colour_code ne 'transparent' && (substr($colour_code,0,1) ne '#'));  
  }else{
    $colour_code = $default;
  }
  $colour_code =~ s/_/ /g;
  return $colour_code;
}

sub _init_hash{
  my $value=shift;
  $value= {} if(!defined($value));
  return $value;
}
1;
