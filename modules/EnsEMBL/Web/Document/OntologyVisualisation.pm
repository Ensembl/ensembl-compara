=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Document::OntologyVisualisation;

use strict;
use warnings;
no warnings "uninitialized";

use URI::Escape;
use GraphViz;
use Bio::EnsEMBL::DBSQL::OntologyTermAdaptor;
use EnsEMBL::Web::File::Dynamic::Image;


=head1 NAME

OntologyVisualisation - Shows a graph for a list of highlighted and normal ontology terms. 
Terms an be clustered by a number of accessions. 
The module generates images + image map htmlscript to restart an Ensembl server

=head1 DESCRIPTION

Shows a graph for a list of highlighted and normal ontology terms. 
Terms an be clustered by a number of accessions. 
The module generates images + image map htmlscript to restart an Ensembl server.

example:
  my $ontovis = EnsEMBL::Web::Tools::OntologyVisualisation->new(
    $ontology_term_adaptor,
    $go_dir,
    $go_url,
    $go_id_url,
    $image_background_colour,
    $node_fill_colour,
    $node_font_colour,
    $node_border_colour,
    $non_highlight_fill_colour,
    $non_highlight_font_colour,
    $non_highlight_border_colour,
    $goslim_goa_fill,
    $goslim_goa_font,
    $goslim_goa_border,
    $get_relation_type_colour
  );
  
  $ontovis->add_cluster_by_parent_accession('GO:0005575');
  $ontovis->add_cluster_by_parent_accession('GO:0008150');
  $ontovis->add_cluster_by_parent_accession('GO:0003674');
  
  $ontovis->normal_term_accessions(keys %$go_hash);
  $ontovis->highlighted_term_accessions(keys %$go_slim_hash);
  
  $html= $ontovis->render;

=head1 AUTHOR

Maurice Hendrix <mh18@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list dev@ensembl.org 

=cut

=head2 constructor

 Colours are in hex format may be preceeded by #, alternatively 'transparent' is allowed for a transparant "colour"
 Arg[1]      : A Bio::EnsEMBL::DBSQL::OntologyTermAdaptor to access the ontology API
 Arg[2]      : The base dir on the local file system, where the generated images can be stored
 Arg[3]      : The external base url to the base dir (arg[2])
 Arg[4]      : the default base url that nodes should lik to, ###ID### will be replaced by the term accession, these can also be set on a per cluster basis
 Arg[5]      : the background colour for the images (optional)
 Arg[6]      : the fill colour for normal (non highlighted and non generated) nodes (optional)
 Arg[7]      : the font colour for normal (non highlighted and non generated) nodes (optional)
 Arg[8]      : the border colour for normal (non highlighted and non generated) nodes (optional)
 Arg[9]      : the fill colour for non highlighted nodes (optional)
 Arg[10]     : the font colour for non highlighted nodes (optional)
 Arg[11]     : the border colour for non highlighted nodes (optional)
 Arg[12]     : the fill colour for highlighted nodes (optional)
 Arg[13]     : the font colour for highlighted nodes (optional)
 Arg[14]     : the border colour for highlighted nodes (optional)
 Arg[15]     : Either of the following: (optional)
                    the colour for all relationshp arrows & labels
                    a function f(x::relation_name)->colour
 
 Example     : my $ontovis = EnsEMBL::Web::Tools::OntologyVisualisation->new(
                 $ontology_term_adaptor,
                 $go_dir,
                 $go_url,
                 $go_id_url,
                 $image_background_colour,
                 $node_fill_colour,
                 $node_font_colour,
                 $node_border_colour,
                 $non_highlight_fill_colour,
                 $non_highlight_font_colour,
                 $non_highlight_border_colour,
                 $goslim_goa_fill,
                 $goslim_goa_font,
                 $goslim_goa_border,
                 $get_relation_type_colour
               );
 Description : creates a ne OntologyVisualisation object
 Return type : EnsEMBL::Document::OntologyVisualisation

=cut

sub new {
  my $class = shift;
  my $self;
  $self->{hub} = shift;
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
  $self->{_highlighted_fill_colour}=_format_colour_code(shift,'transparent');
  $self->{_highlighted_font_colour}=_format_colour_code(shift,'000000');
  $self->{_highlighted_border_colour}=_format_colour_code(shift,'000000');
  $self->{_get_relation_type_colour}=shift;
  
  $self->{_existing_terms}={};
  $self->{_node_descriptions}={};
  $self->{_existing_edges}={};
  my @array=();
  $self->{_normal_term_accessions}=\@array;
  $self->{_highlighted_term_accessions}=\@array;
  $self->{_highlighted_subsets}=\@array;
  $self->{_clusters}={};
  $self->{_idurl_per_cluster}= {};
  
  if(defined($self->{_get_relation_type_colour}) && ref $self->{_get_relation_type_colour} ne "CODE"){
    $self->{_get_relation_type_colour}=_format_colour_code($self->{_get_relation_type_colour},'000000');
  }
  bless $self, $class;
  return $self;
}


=head2 getter/setter for existing_terms

 Arg[1]      : An hashref of existing terms (optional)
 Description : getter/setter for existing_terms
 Return type : arrayref

=cut

sub existing_terms{
  my $self=shift;
  my $existing_terms= shift;
  $self->{_existing_terms} = $existing_terms if defined($existing_terms);
  return $self->{_existing_terms};
}


=head2 getter/setter for node_descriptions hash

 Arg[1]      : An hashref of node_descriptions hash (optional)
 Description : getter/setter for node_descriptions hash
 Return type : arrayref

=cut

sub node_descriptions{
  my $self=shift;
  my $node_descriptions= shift;
  $self->{_node_descriptions} = $node_descriptions if defined($node_descriptions);
  return $self->{_node_descriptions};
}

=head2 getter/setter for existing_edges hash

 Arg[1]      : An hashref of existing_edges hash (optional)
 Description : getter/setter for existing_edges hash
 Return type : arrayref

=cut

sub existing_edges{
  my $self=shift;
  my $existing_edges= shift;
  $self->{_existing_edges} = $existing_edges if defined($existing_edges);
  return $self->{_existing_edges};
}

=head2 getter/setter for the base dir on the local file system, where the generated images can be stored

 Arg[1]      : An string (base dir) (optional)
 Description : getter/setter for the base dir on the local file system, where the generated images can be stored
 Return type : string (dir)

=cut

sub img_base_dir{
  my $self=shift;
  my $img_base_dir = shift;
  $self->{_img_base_dir}= $img_base_dir if defined($img_base_dir);
  return $self->{_img_base_dir};
}

=head2 getter/setter for the external base url to the base dir

 Arg[1]      : An string (base url) (optional)
 Description : getter/setter for the external base url to the base dir
 Return type : string (url)

=cut

sub img_base_url{
  my $self=shift;
  my $img_base_url = shift;
  $self->{_img_base_url}= $img_base_url if defined($img_base_url);
  return $self->{_img_base_url};
}

=head2 getter/setter for the default base url that nodes should lik to, ###ID### will be replaced by the term accession, these can also be set on a per cluster basis

 Arg[1]      : An string (id url) (optional)
 Description : getter/setter for the default base url that nodes should lik to, ###ID### will be replaced by the term accession, these can also be set on a per cluster basis
 Return type : string (url)

=cut

sub idurl{
  my $self=shift;
  my $idurl = shift;
  $self->{_idurl}= $idurl if defined($idurl);
  return $self->{_idurl};
}
=head2 get the id_url for a specific accession on a specific cluster

 Arg[1]      : An string accession
 Arg[1]      : An string cluster_name
 Description : getter for a specific accession on a specific cluster
 Return type : string (url)

=cut

sub get_url{
  my $self=shift;
  my $accession=shift;
  my $cluster=shift;
  my $id_url = $self->{_idurl_per_cluster}->{$cluster};
  if(!defined($id_url)){
    $id_url = $self->idurl;
  }
  if ($id_url) {
    $id_url =~ s/(###ID###)/$accession/g;
    if(!$1){
      $id_url .=$accession;
    }  
  }
  return $id_url;
}

=head2 getter/setter for the background colour for the images

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the background colour for the images
 Return type : string (colour)

=cut

sub image_background_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_image_background_colour}= $colour if defined($colour);
  return $self->{_image_background_colour};
}

=head2 getter/setter for the fill colour for normal (non highlighted and non generated) nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the fill colour for normal (non highlighted and non generated) nodes (optional)
 Return type : string (colour)

=cut

sub node_fill_colour{
  my $self=shift;
  my $colour = shift;
  my $term=shift;
  if ($self->_in_highlighted_subsets($term)){
    return $self->highlighted_fill_colour;
  }else{
    if (defined($colour) && $colour ne ''){
      $self->{_node_fill_colour}= $colour ;
    }
    return $self->{_node_fill_colour};
  }
}

=head2 getter/setter for the font colour for normal (non highlighted and non generated) nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the font colour for normal (non highlighted and non generated) nodes (optional)
 Return type : string (colour)

=cut

sub node_font_colour{
  my $self=shift;
  my $colour = shift;
  my $term=shift;
  if ($self->_in_highlighted_subsets($term)){
    return $self->highlighted_font_colour;
  }else{
    if (defined($colour) && $colour ne ''){
      $self->{_node_font_colour}= $colour ;
    }
    return $self->{_node_font_colour};
  }  
}

=head2 getter/setter for the border colour for normal (non highlighted and non generated) nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the border colour for normal (non highlighted and non generated) nodes (optional)
 Return type : string (colour)

=cut

sub node_border_colour{
  my $self=shift;
  my $colour = shift;
  my $term=shift;
  if ($self->_in_highlighted_subsets($term)){
    return $self->highlighted_border_colour;
  }else{
    if (defined($colour) && $colour ne ''){
      $self->{_node_border_colour}= $colour ;
    }
    return $self->{_node_border_colour};
  }
}

=head2 getter/setter for the fill colour for non highlighted nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the fill colour for non highlighted nodes (optional)
 Return type : string (colour)

=cut

sub non_highlight_fill_colour{
  my $self=shift;
  my $colour = shift;
  my $term=shift;
  if ($self->_in_highlighted_subsets($term)){
    return $self->highlighted_fill_colour;
  }else{
    if (defined($colour) && $colour ne ''){
      $self->{_non_highlight_fill_colour}= $colour ;
    }
    return $self->{_non_highlight_fill_colour};
  }
}

=head2 getter/setter for the font colour for non highlighted nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the font colour for non highlighted nodes (optional)
 Return type : string (colour)

=cut

sub non_highlight_font_colour{
  my $self=shift;
  my $colour = shift;
  my $term=shift;
  if ($self->_in_highlighted_subsets($term)){
    return $self->highlighted_font_colour;
  }else{
    if (defined($colour) && $colour ne ''){
      $self->{_non_highlight_font_colour}= $colour ;
    }
    return $self->{_non_highlight_font_colour};
  }    
}

=head2 getter/setter for the border colour for non highlighted nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the border colour for non highlighted nodes (optional)
 Return type : string (colour)

=cut

sub non_highlight_border_colour{
  my $self=shift;
  my $colour = shift;
  my $term=shift;
  if ($self->_in_highlighted_subsets($term)){
    return $self->highlighted_border_colour;
  }else{
    if (defined($colour) && $colour ne ''){
      $self->{_non_highlight_border_colour}= $colour ;
    }
    return $self->{_non_highlight_border_colour};
  }
}

=head2 getter/setter for the fill colour for highlighted nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the fill colour for highlighted nodes (optional)
 Return type : string (colour)

=cut

sub highlighted_fill_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_highlighted_fill_colour}= $colour if defined($colour);
  return $self->{_highlighted_fill_colour};
}

=head2 getter/setter for the font colour for highlighted nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the font colour for highlighted nodes (optional)
 Return type : string (colour)

=cut

sub highlighted_font_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_highlighted_font_colour}= $colour if defined($colour);
  return $self->{_highlighted_font_colour};
}

=head2 getter/setter for the border colour for highlighted nodes (optional)

 Arg[1]      : An string (colour) (optional)
 Description : getter/setter for the border colour for highlighted nodes (optional)
 Return type : string (colour)

=cut

sub highlighted_border_colour{
  my $self=shift;
  my $colour = shift;
  $self->{_highlighted_border_colour}= $colour if defined($colour);
  return $self->{_highlighted_border_colour};
}

=head2 getter/setter for an arrayref of normal term accessions

 Arg[1]      : An arrayref
 Description : getter/setter for an arrayref of normal term accessions
 Return type : arrayref

=cut

sub normal_term_accessions{
  my $self=shift;
  my @normal_term_accessions = @_;
  $self->{_normal_term_accessions}=\@normal_term_accessions if (scalar(@normal_term_accessions)>0);
  return $self->{_normal_term_accessions};
}

=head2 getter/setter for an arrayref of highlighted term accessions

 Arg[1]      : An arrayref
 Description : getter/setter for an arrayref of highlighted term accessions
 Return type : arrayref

=cut

sub highlighted_term_accessions{
  my $self=shift;
  my @highlighted_term_accessions = @_;
  $self->{_highlighted_term_accessions}=\@highlighted_term_accessions if (@highlighted_term_accessions);
  return $self->{_highlighted_term_accessions};
}

=head2 getter/setter for an arrayref of highlighted term accessions

 Arg[1]      : An arrayref
 Description : getter/setter for an arrayref of highlighted term accessions
 Return type : arrayref

=cut

sub highlighted_subsets{
  my $self=shift;
  my @highlighted_subsets = @_;
  $self->{_highlighted_subsets}=\@highlighted_subsets if (@highlighted_subsets);
  return $self->{_highlighted_subsets};
}

=head2 getter/setter for the Bio::EnsEMBL::DBSQL::OntologyTermAdaptor used to access the ontology API

 Arg[1]      : Bio::EnsEMBL::DBSQL::OntologyTermAdaptor
 Description : getter/setter for the Bio::EnsEMBL::DBSQL::OntologyTermAdaptor used to access the ontology API
 Return type : Bio::EnsEMBL::DBSQL::OntologyTermAdaptor

=cut

sub ontology_term_adaptor{
  my $self=shift;
  my $ontology_term_adaptor = shift;
  $self->{_ontology_term_adaptor}= $ontology_term_adaptor if defined($ontology_term_adaptor);
  return $self->{_ontology_term_adaptor};
}

=head2 add a cluster to the OntologyVisualisation for the accession. All children of this term will be in its cluster

 Arg[1]      : a string, the accession of the term or which to add a cluster
 Description : add a cluster to the OntologyVisualisation for the accession. All children of this term will be in its cluster
 Return type : void

=cut

sub add_cluster_by_parent_accession{
  my $self=shift;
  my $new_cluster = shift;
  my $idurl = shift;

  if(defined $idurl){
    $self->{_idurl_per_cluster}->{$new_cluster}=$idurl;
  }
  if(!$self->{_clusters}->{$new_cluster}){
    $self->{_clusters}->{$new_cluster}= GraphViz->new(nodesep=>0.5, ranksep=>2,layout => 'dot', ratio => 'compress', bgcolor=>$self->image_background_colour, style=>'filled', landscape=>'true',
      nojustify=>'false',node => {nodesep=>'0.03',height=>'0.02', width=>'0.02',nojustify=>'false', margin=>'0.03,0', ratio => 'compress',shape => 'box', fontsize => '10pt', fontnames=>'ps'});
  }
}

=head2 render the html & generate the images

 Description : render the html & generate the images
 Return type : string (html), the images are stored in the image_base_dir set

=cut

sub render{
  my $self=shift;
  my $ontology_term_adaptor = $self->ontology_term_adaptor;
  if (!defined($ontology_term_adaptor)){ die 'Bio::EnsEMBL::DBSQL::OntologyTermAdaptor ontology_term_adaptor not defined'};

  for my $key ( @{$self->highlighted_term_accessions} ) {#add the nodes we retreived, and highlight them
    $self->_add_node($key, $self->highlighted_border_colour,$self->highlighted_fill_colour, $self->highlighted_font_colour);
  }

  for my $key ( @{$self->normal_term_accessions} ) {#add the nodes we retreived
    my $term = $ontology_term_adaptor->fetch_by_accession($key);
    $self->_add_node($key, $self->node_border_colour('', $term), $self->{_node_fill_colour}, $self->{_node_font_colour});
  }

  my @all_terms =  @{$self->normal_term_accessions} ;
  push(@all_terms,@{$self->highlighted_term_accessions});
  my $added = {};
  for my $key ( @all_terms ) {#add all parents of the nodes we retreived
    my $term = $ontology_term_adaptor->fetch_by_accession($key);
    $self->_add_parents($term,$ontology_term_adaptor,$added);
  }

  my $return_html='';
  my $images_html='';
  mkdir($self->img_base_dir);
  foreach(keys %{$self->{_clusters}}){
    my $cluster=$self->{_clusters}->{$_};
    
    my $image = EnsEMBL::Web::File::Dynamic::Image->new(
                                                        'hub'             => $self->{'hub'},
                                                        'name_timestamp'  => 1,
                                                        'extension'       => 'png',
                                                        );

    $image->write($cluster->as_png);
  
    my $image_map = $cluster->as_cmapx;
    $image_map =~ s/title="([^"]*)" alt=""/ title="$self->{_node_descriptions}->{$1}" alt="$self->{_node_descriptions}->{$1}"/g;
	  $image_map =~ s/id="test" name="test"/id="$_" name="$_"/g;
	  $return_html.=$image_map;
    #$images_html.=qq(<img style="float:none;" usemap="#).$_.qq(" src=").$self->img_base_url.$file.qq(" border="0">);
    $images_html.=qq(<img style="float:none;" usemap="#).$_.qq(" src=").$image->URL.qq(" border="0">);
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
  my $cluster_name= $self->_get_cluster_name($term, $ontology_term_adaptor);
  my $cluster = $self->_get_cluster($cluster_name);
  
  #add the node if needed
  if(! $self->existing_terms->{$key}){
    $self->existing_terms->{$key}=1;
    my $node_name = $self->_format_node_name($term);
    $cluster->add_node($node_name,URL=>$self->get_url($term->accession,$cluster_name), style=>'filled', color=>$border_colour,fillcolor=>$fill_colour, fontcolor=>$font_colour);
  }  
}

sub _get_height{ #0.16 inch per line
  my $self=shift;
  my $node_name=shift;
  my $count=1;
  while ($node_name =~ /\n/g) { $count++ }
  return $count*.16;
}

sub _get_width{
  my $self=shift;
  my $node_name=shift;
  my $length=0;
  foreach(split(/\n/, $node_name)){
    $length=($length< length($_))?length($_):$length;
  }
  return $length*.085;
}

sub _add_parents{
  my $self=shift;
  my $term = shift;
  my $ontology_term_adaptor = shift;
  my $added = shift || {};
  my $edge_colour_function = $self->{_get_relation_type_colour};

  return if exists $added->{$term->accession};
  $added->{$term->accession} = undef;

  my $cluster_name= $self->_get_cluster_name($term, $ontology_term_adaptor);
  my $cluster = $self->_get_cluster($cluster_name);

  my %parents = (
    'is_a' => $term->parents('is_a'),
    'part_of' => $term->parents('part_of')
  );

  foreach my $relation (keys %parents) {
    foreach my $trm (@{$parents{$relation} || []}){
      next unless $trm;
      if(! $self->existing_terms->{$trm->accession}){
        $self->existing_terms->{$trm->accession}=1;
        my $node_name = $self->_format_node_name($trm);
        $cluster->add_node($node_name, URL=>$self->get_url($trm->accession,$cluster_name), style=>'filled', color=>$self->node_border_colour('',$trm),
      fillcolor=>$self->non_highlight_fill_colour('',$trm), fontcolor=>$self->non_highlight_font_colour('',$trm));
      }
      if(! $self->existing_edges->{$term->accession.$trm->accession.$relation}){
        $self->existing_edges->{$term->accession.$trm->accession.$relation}=1;
        my $edge_colour;
        if(ref $edge_colour_function eq 'CODE'){
          $edge_colour = _format_colour_code(&$edge_colour_function($relation),'000000');
        }else{
          $edge_colour = _format_colour_code($edge_colour_function,'000000');
        }
        $cluster->add_edge($self->_format_node_name($trm)=>$self->_format_node_name($term), label=>$relation, color=>$edge_colour, fontcolor=>
        $edge_colour, dir=>'back', fontsize => '8pt'); #since we want a bottom-up tree, we add the link in the opposite direction and then set the directed option to backward.
      }
      $self->_add_parents($trm,$ontology_term_adaptor, $added);
    }
  }
}

sub _get_cluster{
  my $self=shift;
  my $name = shift;  
  
  return $self->{_clusters}->{$name};
}

sub _get_cluster_name{
  my $self=shift;
  my $term = shift;
  my $ontology_term_adaptor = shift;

  my $all_parents = $ontology_term_adaptor->fetch_all_by_descendant_term($term);
  #find out which cluster this belongs to
  my $cluster_name;

  if($self->{_clusters}->{$term->accession}){
    $cluster_name = $term->accession;
  }else{
    foreach(@$all_parents){
      if($self->{_clusters}->{$_->accession}){
        $cluster_name = $_->accession;
      }
    }
  }

  if(!defined($cluster_name)){
    $self->add_cluster_by_parent_accession("\n");
    $cluster_name="\n";
  }
  return $cluster_name;
}

sub _format_node_name{
  my $self=shift;
  my $trm = shift;
  my $return_string = $trm->accession;
  $return_string=$trm->name;
  $return_string=~ s/_/ /g;
  $return_string=~s/ /\n/g;

  my $descr=$trm->name;
  my $key = $return_string;
  $descr =~ s/_/ /g;
  $key=~ s/\n/\\n/g;
  $key=~ s/-/&#45;/g;
  $self->node_descriptions->{$key}=$trm->accession." ".$descr;
  return $return_string;
}

sub _get_image_file_name{
  return _random_image_name().".png";
}

sub _random_image_name {
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

sub _in_highlighted_subsets{
  my $self=shift;
  my $term=shift;
  my $found =0;
  if(defined($term)){
   my @subsets = @{$term->subsets};
   my @highlighted_subsets = @{$self->highlighted_subsets};
   for (my $i=0; $i< scalar @subsets && !$found; $i++){
     for (my $j=0; $j< scalar @highlighted_subsets && !$found; $j++){
       $found = $subsets[$i] eq $highlighted_subsets[$j];
     }
    }
  }
  return $found;
}
1;
