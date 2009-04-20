package EnsEMBL::Web::Component::Go;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Component::Feature;
use EnsEMBL::Web::Document::SpreadSheet;

our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub accession {
  my( $panel, $object ) = @_;
  my $acc_id = $object->param('display') || $object->param('acc');
  my $label = 'GO Accession';
  my $name;
  return unless $object->name;
  my $html = '<p>';
  if ( $object->param('display') ) {
    $name = $object->name;
    $html .= qq(The following genes have been mapped to Gene Ontology ID: <a href="goview?acc=$acc_id">$acc_id</a> [$name]);
  } elsif ($acc_id) {
    $name = $object->name;
    $html .= qq(<strong>$acc_id</strong> [$name]);
  } else {
    $html .= '(none selected)';
  }
  $html .= '</p>';
  $panel->add_row( $label, $html );
  return 1;
}

sub gene_acc {
  my( $panel, $object ) = @_;

  my $acc_id = $object->acc_id;
  return unless $object->name;
  my $name = $object->name;
  $panel->add_row( 'GO Accession', $acc_id ? "<p><strong>$acc_id</strong> ($name)</p>" : "<p>(none selected)</p>" );
  return 1;
}

sub database {
    my( $panel, $object ) = @_;

    my $label = 'GO Database';
    my $html = qq(
<p>GO data is provided by the <a href="http://www.geneontology.org/">Gene Ontology Consortium</a></p>
    );
    $panel->add_row( $label, $html );
    return 1;

}

# goview needs its own search box, as the sitewide search doesn't have
# a connection to the GO database

sub search {
  my( $panel, $object ) = @_;
  $panel->add_row( 'Search GO', "@{[ $panel->form( 'search' )->render ]}" );
  return 1;
}

sub search_form {
  my( $panel, $object ) = @_;
   
  my $go_id = $object->param('acc');
  my $go_str = '';
  if ($go_id) {
    $go_str = $go_id.',';
  }
  
  my $form = EnsEMBL::Web::Form->new( 'gosearch', "/@{[$object->species]}/goview", 'get' );
 
  $form->add_element(
    'type' => 'String', 'required' => 'yes',
    'label' => "Search GO database for:",  'name' => 'query',
    'value' => $go_id, 'style' => 'medium',
    'notes' => "[ e.g. $go_str *vesicle, *calcium binding* ]"
  );

  $form->add_element('type'  => 'Submit', 'value' => 'Search');

  return $form;
}

sub show_karyotype {
  my( $panel, $object ) = @_;
                                                                                
  $object->load_genes();
  my $karyotype = EnsEMBL::Web::Component::Feature::create_karyotype($panel, $object);

  $panel->add_row( 'Gene Location', $karyotype->render );
  return 1;
}

#-----------------------------------------------------------------------------

# draws a table-style tree

sub tree {
  my( $panel, $object ) = @_;

  my $species = $object->species;

  if ($object->param('acc') || $object->param('query')) {
    # start building spreadsheet
    my $table = EnsEMBL::Web::Document::SpreadSheet->new();
    $table->add_columns(
      {'key' => 'tree', 'title' => "", 'width' => '60%', 'align' => 'left' },
      {'key' => 'genes', 'title' => "Gene Matches", 'width' => '40%', 'align' => 'center'
},
    );

    # create tree
    my $it = $object->iterator;
    return unless $it;
    my %families = %{$object->families};
    my $id = $object->acc_id;
    my $query = $object->param('query');

    my ($class, $tree, $genes);
    my $depth_limit = 10000;
    while (my $ni = $it->next_node_instance) {
      $tree = '';
      $genes = ''; # clear strings

      my $depth = 2 * $ni->depth;
      my $term = $ni->term;
      my $localid = $term->public_acc();
      my $name = $term->name;
      next if ($ni->depth >= $depth_limit + 1);
      # set highlight styles
      my $is_head = 0;
      my $is_match = 0;
      if ($name eq "biological_process" || $name eq "cellular_component" || $name eq "molecular_function"){
        $is_head = 1;
      } 
      my $current_style  = 'bg3'; 
      # do tree indent
      $tree .= '<div style="padding-left:'.$depth.'em';
      if ($is_head) {
        $tree .= qq(;font-weight:bold);
      }
      $tree .= '">';
      # highlight current GO
      if ($localid eq $id) { # also check for matching IDs
        $is_match = 1;
      } elsif($query) { # check match between name and query string
        my @words = split(/\s+/, $name);
        foreach my $word (@words) {
          $word =~ s/[\(\)]//g; # remove chars that might break regex
          if ($query =~ /$word/) {
            $is_match = 1; 
          }
        }
      }
      if ($is_match) { 
        $depth_limit = $ni->depth() + 1;
         $tree .= qq(<span class="$current_style">$name</span>);
      } else {
        $tree .= $name;
      }
      $tree .= qq(&nbsp;[<a href="/$species/goview?acc=$localid">$localid</a>]</div>);

      # now get gene info
#      my @extgenes = @{$families{$localid}}; 
      my $count = $object->count_genes( $localid );
#       $count = scalar(@extgenes);
      if($count>0){
        $genes .= qq(<a href="/$species/goview?display=$localid;chr_length=200">$count gene(s) </a>\n);
      } else {
        $genes .= '&nbsp;';
      }
      # add completed row to table
      my $data_row = { 'tree'  => $tree, 'genes' => $genes};
      $table->add_row( $data_row );
    }
    $panel->add_row('Go Graph', $table->render);
  }
 return 1;
}

sub family {
  my( $panel, $object ) = @_;

  my $id = $object->param('display');
  my $species = $object->species;

  if ($id) {
    return unless $object->load_genes();
    my $table = EnsEMBL::Web::Document::SpreadSheet->new();

    $table->add_columns(
      {'key' => 'id', 'title' => "Ensembl Gene ID", 'width' => '25%', 'align' => 'left' },
      {'key' => 'desc', 'title' => "Gene Description", 'width' => '35%', 'align' => 'left'},
      {'key' => 'family', 'title' => "Protein Family/Family Description", 'width' => '40%', 'align' => 'left'},
    );

    my @gene_info    = @{$object->get_geneinfo};
    my @family_info  = @{$object->get_faminfo};
    my $gene_total   = scalar(@gene_info);  
    for (my $i=0; $i<$gene_total; $i++) {
       my %gene   = %{$gene_info[$i]};
       my %family = %{$family_info[$i]||{}};

       # start paragraphs for content
       my $id_txt = '<p>';
       my $desc_txt = '<p>';
       my $fam_txt = '<p>';

       # gene ID and evidence
       my $gid     = $gene{'stable_id'};
       my $ev      = $gene{'evidence'};
       $id_txt .= qq(<a href="/$species/geneview?gene=$gid">$gid</a> <span class="small">Evidence:$ev</span>);

       # gene description
       $desc_txt .= $gene{'description'};

       # family ID and description
       if( $family{'stable_id'} ) {
         my $fid     = $family{'stable_id'};
         my $desc    = $family{'description'};
         $fam_txt .= qq(<a href="/$species/familyview?family=$fid">$fid</a><br /><em>$desc</em>);
       } else {
        $fam_txt .= '--';
       }
       # close all paragraphs
       $id_txt .= '</p>';
       $desc_txt .= '</p>';
       $fam_txt .= '</p>';

       # add completed row to table
       my $data_row = { 'id'  => $id_txt, 'desc' => $desc_txt, 'family'=>$fam_txt};
       $table->add_row( $data_row );
     }
     # add table to panel
     $panel->add_row('Gene and Protein Family Information', $table->render);
  }
  return 1;
}

1;
