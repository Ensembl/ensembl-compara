package EnsEMBL::Web::Component::Gene::Family;

### Displays a list of protein families for this gene

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $cdb = shift || $self->object->param('cdb') || 'compara';
  my $object         = $self->object;
  my $sp             = $object->species_defs->DISPLAY_NAME;
  my $families       = $object->get_all_families($cdb);
  my $gene_stable_id = $object->stable_id;

  my $ckey = $cdb eq 'compara_pan_ensembl' ? '_pan_compara' : ''; # hack to add _pan_compara suffix... must be a better way?

  my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { data_table => 1, sorting => [ 'id asc' ] });

  $table->add_columns(
    { key => 'id',          title => 'Family ID',                            width => '20%', align => 'left', sort => 'html'   },
    { key => 'annot',       title => 'Consensus annotation',                 width => '30%', align => 'left', sort => 'string' },
    { key => 'transcripts', title => "Other transcripts in this family", width => '30%', align => 'left', sort => 'html'   },
    { key => 'jalview',     title => 'Multiple alignments',                  width => '20%', align => 'left', sort => 'none'   }
  );
  
  foreach my $family_id (sort keys %$families) {
    my $family     = $families->{$family_id};
    my $row        = { id => "$family_id<br /><br />" };
    my $genes      = $families->{$family_id}{'info'}{'genes'};
    my $url_params = { function => "Genes$ckey", family => $family_id, g => $gene_stable_id };
    
    $row->{'id'}          .= scalar @$genes > 1 ? sprintf('(<a href="%s">%s genes</a>)', $object->_url($url_params), scalar @$genes) : '(1 gene)';
    $row->{'id'}          .= sprintf '<br />(<a href="%s">all proteins in family</a>)',  $object->_url({ function => "Proteins$ckey", family => $family_id });
    $row->{'annot'}        = $families->{$family_id}{'info'}{'description'};
    
    my $fam_obj         = $object->create_family($family_id, $cdb);
    my $ensembl_members = $object->member_by_source($fam_obj, 'ENSEMBLPEP');
    
#----------    
    # get info for transcripts in this family
    my @transcripts;
    foreach (@{$ensembl_members}) {
      my ($member, $attribute) = @{$_};
      my $transcript;
      eval{$transcript = $member->get_Transcript};
      if ($transcript) {
        my $xref_display_id;
        eval{$xref_display_id = $transcript->display_xref->display_id};
        push(@transcripts, {
          stable_id => $transcript->stable_id,
          species => $member->genome_db->name,
          xref_display_id => $xref_display_id, 
        });
      };
    }
    # display limited transcript list, with button to show all
    if (@transcripts) {
      my $limit = 50;
      $row->{'transcripts'} .= '<ul>';
      foreach (0..@transcripts-1) {
        my $url_params = {__clear => 1, species => $transcripts[$_]->{species}, function => "Genes$ckey", family => $family_id, t => $transcripts[$_]->{stable_id}};        
        my $xrd_id = $transcripts[$_]->{xref_display_id} ? "($transcripts[$_]->{xref_display_id})" : '';
        $row->{'transcripts'} .= ($_ < $limit-1) ? '<li>' : qq{<li class="hidden_transcript_${family_id}" style="display:none">};
        $row->{'transcripts'} .= sprintf '<a href="%s">%s</a>&nbsp;%s', $object->_url($url_params), $transcripts[$_]->{stable_id}, $xrd_id;
        $row->{'transcripts'} .= '</li>';
      }
      $row->{'transcripts'} .= '</ul>';
      if (@transcripts > $limit) {
        $row->{'transcripts'} .= qq{     
<div><a href="#" id="toggle_transcript_${family_id}">Show all</a></div>
<script type="text/javascript" charset="utf-8">
\$(document).ready(function(){
  \$("#toggle_transcript_${family_id}").click(function(){
    \$("li.hidden_transcript_${family_id}").toggle();
    \$(this).html(\$(this).html() == "Show all" ? "Show less" : "Show all");
    return false;
  });
});
</script>      
        };
      }
    }
#----------    
    
    my @all_pep_members;
    push @all_pep_members, @$ensembl_members;
    push @all_pep_members, @{$object->member_by_source($fam_obj, 'Uniprot/SPTREMBL')};
    push @all_pep_members, @{$object->member_by_source($fam_obj, 'Uniprot/SWISSPROT')};

    $row->{'jalview'} = $self->jalview_link($family_id, 'Ensembl', $ensembl_members, $cdb) . $self->jalview_link($family_id, '', \@all_pep_members, $cdb) || 'No alignment has been produced for this family.';

    $table->add_row($row);
  }
  
  return $table->render;
}

sub jalview_link {
  my ($self, $family, $type, $refs, $cdb) = @_;
  my $count = @$refs;
  (my $ckey = $cdb) =~ s/compara//;
  my $url   = $self->object->_url({ function => "Alignments$ckey", family => $family });
  #return qq(<p class="space-below">$count $type members of this family <a href="$url">JalView</a></p>);
  return qq(<p class="space-below">$count $type members of this family</p>);
}

1;
