# $Id$

package EnsEMBL::Web::Component;

use strict;

use base qw(EnsEMBL::Web::Root Exporter);

use Exporter;

our @EXPORT_OK = qw(cache cache_print);
our @EXPORT = @EXPORT_OK;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use Text::Wrap qw(wrap);

use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;

use EnsEMBL::Web::Document::Image;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::TmpFile::Text;

sub new {
  my $class = shift;
  
  my $self = {
    'model' => shift,
    'id' => [split /::/, $class]->[-1] . 'Panel'
  };
  
  bless $self, $class;
  $self->_init;
  
  return $self;
}

sub id {
  my $self = shift;
  $self->{'id'} = shift if @_;
  return $self->{'id'};
}

sub model { return $_[0]->{'model'}; }
sub hub { return $_[0]->{'model'}{'_hub'}; }

sub object {
## Tries to be backwards compatible!
  my $self = shift;
  $self->{'object'} = shift if @_;
  my $object;
  if ($self->{'model'}) {
    $object = $self->{'model'}->object;
  }
  else { 
    $self->{'object'};
  }
  return $object;
}

sub cacheable {
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub ajaxable {
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub cache {
  my ($panel, $obj, $type, $name) = @_;
  my $cache = new EnsEMBL::Web::TmpFile::Text(
    prefix   => $type,
    filename => $name,
  );
  return $cache;
}

sub cache_print {
  my ($cache, $string_ref) = @_;
  $cache->print($$string_ref) if $string_ref;
}

sub site_name   { return $SiteDefs::SITE_NAME || $SiteDefs::ENSEMBL_SITETYPE; }
sub image_width { return $ENV{'ENSEMBL_IMAGE_WIDTH'}; }
sub has_image   { return 0; }
sub cache_key   { return undef; }
sub caption     { return undef; }
sub _init       { return; }

sub _error   { return shift->_info_panel('error',   @_);  } # Fatal error message. Couldn't perform action
sub _warning { return shift->_info_panel('warning', @_ ); } # Error message, but not fatal
sub _info    { return shift->_info_panel('info',    @_ ); } # Extra information 
sub _hint    { my ($self, $id, $caption, $desc, $width) = @_; return $self->_info_panel('hint hint_flag', $caption, $desc, $width, $id); } # Extra information, hideable

sub _info_panel {
  my ($self, $class, $caption, $desc, $width, $id) = @_;
  
  return sprintf (
    '<div%s style="width:%s" class="%s"><h3>%s</h3><div class="error-pad">%s</div></div>',
    $id ? qq{ id="$id"} : '',
    $width || $self->image_width . 'px', 
    $class, 
    $caption, 
    $desc
  );
}

sub ajax_url {
  my ($self, $function_name, $no_query_string) = @_;
  
  my $hub = $self->hub;
  my ($ensembl, $plugin, $component, $type, $module) = split '::', ref $self;
  
  my $url = join '/', $hub->species_defs->species_path, 'Component', $hub->type, $plugin, $module;
  $url .= "/$function_name" if $function_name && $self->can("content_$function_name");
  $url .= '?_rmd=' . substr md5_hex($ENV{'REQUEST_URI'}), 0, 4;
  $url .= ";$ENV{'QUERY_STRING'}" unless $no_query_string;
  
  return $url;
}

sub glossary_mouseover {
  my ($self, $entry, $display_text) = @_;
  $display_text ||= $entry;
  
  my %glossary = $self->hub->species_defs->multiX('ENSEMBL_GLOSSARY');
  (my $text = $glossary{$entry}) =~ s/<.+?>//g;

  return $text ? qq{<span class="glossary_mouseover">$display_text<span class="glossary_popup">$text</span></span>} : $display_text;
}

# Attach all das sources from an image config
sub _attach_das {
  my ($self, $wuc) = @_;

  # Look for all das sources which are configured and turned on
  my @das_nodes = map {
    $_->get('glyphset') eq '_das' && $_->get('display') ne 'off' ? @{$_->get('logicnames')||[]} : ()
  }  $wuc->tree->nodes;
  
  return unless @das_nodes; # Return if no sources to be drawn
 
  # Check to see if they really exists, and get entries from get_all_das call
  my %T = %{$ENSEMBL_WEB_REGISTRY->get_all_das($self->hub->species)};
  my @das_sources = @T{@das_nodes};
  return unless @das_sources; # Return if no sources exist

  # Cache the DAS Coordinator object (with key das_coord)
  $wuc->cache('das_coord',  
    Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(
      -sources => \@das_sources,
      -proxy   => $self->hub->species_defs->ENSEMBL_WWW_PROXY,
      -noproxy => $self->hub->species_defs->ENSEMBL_NO_PROXY,
      -timeout => $self->hub->species_defs->ENSEMBL_DAS_TIMEOUT
    )
  );
}

# Creates a modal-friendly form with hidden elements to automatically pass to handle wizard buttons
sub modal_form {
  my ($self, $name, $action, $options) = @_;
  
  my $object      = $self->object;
  my $form_action = $action;
  my $form_class  = 'std check';
  
  if ($options->{'wizard'}) {
    my $species = $object->type eq 'UserData' ? $object->data_species : $object->species;
    
    $form_action  = $object->species_path($species) if $species;
    $form_action .= sprintf '/%s/Wizard', $object->type;
    
    $form_class .= ' wizard';
  }
  
  my $form = new EnsEMBL::Web::Form($name, $form_action, $options->{'method'} || 'post', $form_class);
  my $label = $options->{'label'} || 'Next >';
  
  if ($options->{'wizard'}) {
    $form->add_button('type' => 'Button', 'name' => 'wizard_back', 'value' => '< Back', 'classes' => [ 'back', 'submit' ]) unless defined $options->{'back_button'} && $options->{'back_button'} == 0;
    
    # Include current and former nodes in _backtrack
    if (my @tracks = $object->param('_backtrack')) {
      foreach my $step (@tracks) {
        next unless $step;
        $form->add_element('type' => 'Hidden', 'name' => '_backtrack', 'value' => $step);
      }
    }
    
    $form->add_button('type'  => 'Submit', 'name' => 'wizard_submit', 'value' => $label);
    $form->add_element('type' => 'Hidden', 'name' => '_backtrack',    'value' => $object->action);
    $form->add_element('type' => 'Hidden', 'name' => 'wizard_next',   'value' => $action);
  } elsif (!$options->{'no_button'}) {
    $form->add_button('type' => 'Submit', 'name' => 'submit', 'value' => $label);
  }

  return $form;
}

sub new_image {
  my $self = shift;
  my $object = $self->object;
  
  my %formats = EnsEMBL::Web::Constants::FORMATS;
  my ($image_config, $id);
  
  if (ref $_[0] eq 'ARRAY') {
    my %image_config_types = map $_->{'type'}, grep $_->isa('EnsEMBL::Web::ImageConfig'), @{$_[0]};
    $image_config = $_[0][1];
    $id = join '--', keys %image_config_types;
  } else {
    $image_config = $_[1];
    $id = $image_config->{'type'}
  }
  
  $self->id($id);
  
  # Set text export on image config
  $image_config->set_parameter('text_export', $object->param('export')) if $formats{$object->param('export')}{'extn'} eq 'txt';
  
  my $image = new EnsEMBL::Web::Document::Image($object->species_defs);
  $image->drawable_container = new Bio::EnsEMBL::DrawableContainer(@_);
  $image->prefix($object->prefix) if $object->prefix;
  
  return $image;
}

sub new_vimage {
  my $self = shift;
  my $object = $self->object;
  
  $self->id($_[1]->{'type'}); # $_[1] is image config
  
  my $image = new EnsEMBL::Web::Document::Image($object->species_defs);
  $image->drawable_container = new Bio::EnsEMBL::VDrawableContainer(@_);
  
  return $image;
}

sub new_karyotype_image {
  my ($self, $image_config) = @_;
  my $object = $self->object;
  
  $self->id($image_config->{'type'}) if $image_config;
  
  my $image = new EnsEMBL::Web::Document::Image($self->hub->species_defs);
  $image->{'object'} = $object;
  
  return $image;
}

sub _export_image {
  my ($self, $image, $flag) = @_;
  my $hub = $self->model->hub;
  
  $image->{'export'} = 'iexport' . ($flag ? " $flag" : '');
  
  my ($format, $scale) = $hub->param('export') ? split /-/, $hub->param('export'), 2 : ('', 1);
  $scale eq 1 if $scale <= 0;
  
  my %formats = EnsEMBL::Web::Constants::FORMATS;
  
  if ($formats{$format}) {
    $image->drawable_container->{'config'}->set_parameter('sf',$scale);
    (my $comp = ref $self) =~ s/[^\w\.]+/_/g;
    my $obj_filename = $self->object ? $self->object->_filename : $hub->filename;
    my $filename = sprintf '%s-%s-%s.%s', $comp, $obj_filename, $scale, $formats{$format}{'extn'};
    
    if ($hub->param('download')) {
      $hub->input->header(-type => $formats{$format}{'mime'}, -attachment => $filename);
    } else {
      $hub->input->header(-type => $formats{$format}{'mime'}, -inline => $filename);
    }

    if ($formats{$format}{'extn'} eq 'txt') {
      print $image->drawable_container->{'export'};
      return 1;
    }

    $image->render($format);
    return 1;
  }
  
  return 0;
}

sub _matches {
  my ($self, $key, $caption, @keys) = @_;
  
  my $object = $self->object;
  my $label  = $self->hub->species_defs->translate($caption);
  my $obj    = $object->Obj;

  # Check cache
  if (!$object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($obj)};
    
    return unless @similarity_links;
    
    $self->_sort_similarity_links(@similarity_links);
  }

  my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;

  return unless @links;

  my $db    = $object->get_db;
  my $entry = lc(ref $obj);
  $entry =~ s/bio::ensembl:://;

  # add table call here
  my $html;
  
  if ($self->hub->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $html = '<p></p>';
  } else {
    $html = "<p><strong>This $entry corresponds to the following database identifiers:</strong></p>";
  }
  
  $html .= '<table cellpadding="4">';
  
  @links = $self->remove_redundant_xrefs(@links) if $keys[0] eq 'ALT_TRANS';
  
  return unless @links;
  
  my $old_key = '';
  
  foreach my $link (@links) {
    my ($key, $text) = @$link;
    
    if ($key ne $old_key) {
      $html .= '<div class="small">GO mapping is inherited from swissprot/sptrembl</div>' if $old_key eq 'GO';
      $html .= '</td></tr>' if $old_key ne '';
      $html .= qq{<tr><th style="white-space: nowrap; padding-right: 1em">$key:</th><td>};
      
      $old_key = $key;
    }
    
    $html .= $text;
  }
  
  $html .= '</td></tr></table>';

  return $html;
}

sub _sort_similarity_links {
  my $self = shift;
  my @similarity_links = @_;
  my $object   = $self->object;
  my $database = $object->database;
  my $db       = $object->get_db;
  my $urls     = $object->ExtURL;
  my $fv_type  = $object->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
  my (%affy, %exdb);
  
  foreach my $type (sort {
    $b->priority        <=> $a->priority ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links) {
    my $link = '';
    my $join_links = 0;
    my $externalDB = $type->database;
    my $display_id = $type->display_id;
    my $primary_id = $type->primary_id;
    
    next if $type->status eq 'ORTH';                            # remove all orthologs
    next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
    next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
    next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
    next if $externalDB eq 'Vega_transcript';
    next if $externalDB eq 'Vega_translation';
    next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs
    
    if ($externalDB eq 'GO' || $externalDB eq 'goslim_goa') {
      push @{$object->__data->{'links'}{'go'}}, $display_id;
      next;
    } elsif ($externalDB eq 'GKB') {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}}, $type;
      next;
    }
    
    my $text = $display_id;
    
    (my $A = $externalDB) =~ s/_predicted//;
    
    if ($urls and $urls->is_linked($A)) {
      my $link = $urls->get_url($A, $primary_id);
      my $word = $display_id;
      $word .= " ($primary_id)" if $A eq 'MARKERSYMBOL';
      
      if ($link) {
        $text = qq{<a href="$link">$word</a>};
      } else {
        $text = $word;
      }
    }
    
    if ($type->isa('Bio::EnsEMBL::IdentityXref')) {
      $text .= ' <span class="small"> [Target %id: ' . $type->target_identity . '; Query %id: ' . $type->query_identity . ']</span>';
      $join_links = 1;
    }
    
    if ($object->species_defs->ENSEMBL_PFETCH_SERVER
	&& $externalDB =~ /^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i
        && ref($object->Obj) eq 'Bio::EnsEMBL::Transcript' ) {
      my $seq_arg = $display_id;
      $seq_arg = "LL_$seq_arg" if $externalDB eq 'LocusLink';
      $text .= sprintf ' [<a href="%s/Transcript/Similarity/Align?t=%s;sequence=%s;db=%s">align</a>] ', $object->species_defs->species_path, $object->stable_id, $seq_arg, $db;
    }
    
    $text .= sprintf ' [<a href="%s">Search GO</a>]', $urls->get_url('GOSEARCH', $primary_id) if $externalDB =~ /^(SWISS|SPTREMBL)/i; # add Search GO link;
    
    if ($type->description) {
      (my $D = $type->description) =~ s/^"(.*)"$/$1/;
      
      $text .= '<br />' . encode_entities($D);
      $join_links = 1;
    }
    
    if ($join_links) {
      $text = qq{\n <div>$text};
    } else {
      $text = qq{\n <div class="multicol">$text};
    }
    
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if ($externalDB =~ /^AFFY_/i) {
      next if $affy{$display_id} && $exdb{$type->db_display_name}; # remove duplicates
      
      $text = qq{\n  <div class="multicol"> $display_id};
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }

    # add link to featureview
    my $link_name = $fv_type eq 'OligoFeature' ? $display_id : $primary_id;
    my $link_type = $fv_type eq 'OligoFeature' ? $fv_type : "${fv_type}_$externalDB";
    
    my $k_url = $self->model->hub->url({
      type   => 'Location',
      action => 'Genome',
      id     => $link_name,
      ftype  => $link_type
    });
    
    $text .= qq{  [<a href="$k_url">view all locations</a>]};
    $text .= '</div>';
    
    push @{$object->__data->{'links'}{$type->type}}, [ $type->db_display_name || $externalDB, $text ];
  }
}

sub remove_redundant_xrefs {
  my ($self, @links) = @_;
  my %priorities;

  foreach my $link (@links) {
    my ($key, $text) = @$link;
    $priorities{$key} = $text if $text =~ />OTT|>ENST/;
  }

  foreach my $type (
    'Transcript having exact match between ENSEMBL and HAVANA',
    'Ensembl transcript having exact match with Havana',
    'Havana transcript having same CDS',
    'Ensembl transcript sharing CDS with Havana',
    'Havana transcript'
  ) {
    if ($priorities{$type}) {
      my @munged_links;
      $munged_links[0] = [ $type, $priorities{$type} ];
      return @munged_links;;
    }
  }
  
  return @links;
}

sub transcript_table {
  my $self = shift;
  
  my $object    = $self->object;
  my $page_type = ref($self) =~ /::Gene\b/ ? 'gene' : 'transcript';
  
  my $description = encode_entities($object->gene_description);
  $description    = '' if $description eq 'No description';
  
  if ($description) {
    my ($edb, $acc);
    
    if ($object->get_db eq 'vega') {
      $edb = 'Vega';
      $acc = $object->Obj->stable_id;
      $description .= sprintf ' <span class="small">%s</span>', $object->get_ExtURL_link("Source: $edb", $edb . '_' . lc $page_type, $acc);
    } else {
      $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
      $description =~ s/\[\w+:([-\w\/\_]+)\;\w+:([\w\.]+)\]//g;
      ($edb, $acc) = ($1, $2);
      $description .= sprintf ' <span class="small">%s</span>', $object->get_ExtURL_link("Source: $edb $acc", $edb, $acc) if $acc ne 'content';
    }
    
    $description = "<p>$description</p>";
  }
  
  my $url = $self->object->_url({
    type   => 'Location',
    action => 'View',
    r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
  });
  
  my $location_html = sprintf(
    '<a href="%s">%s: %s-%s</a> %s.',
    $url,
    $object->neat_sr_name($object->seq_region_type, $object->seq_region_name),
    $object->thousandify($object->seq_region_start),
    $object->thousandify($object->seq_region_end),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );
  
  # alternative (Vega) coordinates
  if ($object->get_db eq 'vega') {
    my $alt_assemblies = $object->species_defs->ALTERNATIVE_ASSEMBLIES || [];
    my ($vega_assembly) = map { $_ =~ /VEGA/; $_ } @$alt_assemblies;
    
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($object->species, 'vega')->group;
    
    $reg->add_DNAAdaptor($object->species, 'vega', $object->species, 'vega');

    my $alt_slices = $object->vega_projection($vega_assembly); # project feature slice onto Vega assembly
    
    # link to Vega if there is an ungapped mapping of whole gene
    if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
      my $l   = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;
      my $url = $object->ExtURL->get_url('VEGA_CONTIGVIEW', $l);
      
      $location_html .= ' [<span class="small">This corresponds to ';
      $location_html .= sprintf(
        '<a href="%s" target="external">%s-%s</a>',
        $url,
        $object->thousandify($alt_slices->[0]->start),
        $object->thousandify($alt_slices->[0]->end)
      );
      
      $location_html .= " in $vega_assembly coordinates</span>]";
    } else {
      $location_html .= sprintf qq{ [<span class="small">There is no ungapped mapping of this %s onto the $vega_assembly assembly</span>]}, lc $object->type_name;
    }
    
    $reg->add_DNAAdaptor($object->species, 'vega', $object->species, $orig_group); # set dnadb back to the original group
  }
  
  if ($page_type eq 'gene') {
    # Haplotype/PAR locations
    my $alt_locs = $object->get_alternative_locations;
    
    if (@$alt_locs) {
      $location_html .= '
        <p> This gene is mapped to the following HAP/PARs:</p>
        <ul>';
      
      foreach my $loc (@$alt_locs) {
        my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
        
        $location_html .= sprintf('
          <li><a href="/%s/Location/View?l=%s:%s-%s">%s : %s-%s</a></li>', 
          $object->species, $altchr, $altstart, $altend, $altchr,
          $object->thousandify($altstart),
          $object->thousandify($altend)
        );
      }
      
      $location_html .= '
        </ul>';
    }
  }
  
  my $html = qq{
    $description
    <dl class="summary">
      <dt>Location</dt>
      <dd>
        $location_html
      </dd>
    </dl>
  };
  
  my $gene = $object->gene;
  
  if ($gene) {
    my $transcript  = $page_type eq 'transcript' ? $object->stable_id : $object->param('t');
    my $transcripts = $gene->get_all_Transcripts;
    my $count       = @$transcripts;
    my $plural_1    = 'are';
    my $plural_2    = 'transcripts';
    my $action      = $object->action;
    my %biotype_rows;
    
    my %url_params = (
      type     => 'Transcript',
      action   => $page_type eq 'gene' || $action eq 'ProteinSummary' ? 'Summary' : $action,
      function => undef
    );
    
    if ($count == 1) { 
      $plural_1 = 'is';
      $plural_2 =~ s/s$//;
    }
    
    my $label = "There $plural_1 $count $plural_2 in this gene:";
    
    if ($page_type eq 'transcript') {
      my $gene_id  = $gene->stable_id;
      my $gene_url = $object->_url({
        type   => 'Gene',
        action => 'Summary',
        g      => $gene_id
      });
    
      $label = qq{This transcript is a product of gene <a href="$gene_url">$gene_id</a> - $label};
    }
    
    $html .= sprintf(qq{
    <dl class="summary">
      <dt>%s</dt>
      <dd><p class="toggle_text" id="transcripts_text">%s <span class="toggle_button">Hide transcripts</span></p></dd>
    </dl>
    <table class="toggle_table data_table fixed_width" id="transcripts" summary="List of transcripts for this gene - along with translation information and type">
      <thead>
        <tr>
          <th>Name</th>
          <th class="sort_html">Transcript ID</th>
          <th class="sort_numeric">Length (bp)</th>
          <th class="sort_html">Protein ID</th>
          <th class="sort_numeric">Length (aa)</th>
          <th class="sort_html">Biotype</th> 
    }, $page_type eq 'gene' ? 'Transcripts' : 'Gene', $label);

    $html .= '<th class="sort_html">CCDS</th>' if $object->species =~ /^Homo|Mus/;
    $html .= '
        </tr>
      </thead>
      <tbody>
    ';
    
    foreach (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->stable_id, $_ ] } @$transcripts) {
      my $transcript_length = $_->length;
      my $protein           = 'No protein product';
      my $protein_length    = '-';
      my $ccds              = '-';
      my $url               = $self->object->_url({ %url_params, t => $_->stable_id });
      
      if ($_->translation) {
        $protein = sprintf(
          '<a href="%s">%s</a>',
          $self->object->_url({
            type   => 'Transcript',
            action => 'ProteinSummary',
            t      => $_->stable_id
          }),
          $_->translation->stable_id
        );
        
        $protein_length = $_->translation->length;
      }
      
      if (my @CCDS = grep { $_->dbname eq 'CCDS' } @{$_->get_all_DBLinks}) {
        my %T = map { $_->primary_id => 1 } @CCDS;
        @CCDS = sort keys %T;
        $ccds = join ', ', map $object->get_ExtURL_link($_, 'CCDS', $_), @CCDS;
      }

      (my $biotype = $_->biotype) =~ s/_/ /g;
      
      my $html_row .= sprintf('
        <tr%s>
          <td class="bold">%s</td>
          <td><a href="%s">%s</a></td>
          <td>%s</td>
          <td>%s</td>
          <td>%s</td>
          <td>%s</td>',
        $count == 1 || $_->stable_id eq $transcript ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id,
        $transcript_length,
        $protein,
        $protein_length,
        $self->glossary_mouseover(ucfirst $biotype)
      );

      $html_row .= "<td>$ccds</td>" if $object->species =~ /^Homo|Mus/;
      $html_row .= '</tr>';
      
      $biotype = '.' if $biotype eq 'protein coding';
      $biotype_rows{$biotype} = [] unless exists $biotype_rows{$biotype};
      push @{$biotype_rows{$biotype}}, $html_row;
    }

    # Add rows to transcript table sorted by biotype
    foreach my $type (sort { $a cmp $b } keys %biotype_rows) {
      $html .= $_ for @{$biotype_rows{$type}};
    }   

    $html .= '
      </tbody>
    </table>
    <form class="data_table_config">
      <input type="hidden" name="asStripClasses" value="[]" />
    </form>';
  }
  
  return $html;
}

# Simple subroutine to dump a formatted "warn" block to the error logs - useful when debugging complex
# data structures etc... 
# output looks like:
#
#  ###########################
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  ###########################
sub _warn_block {
  my $self = shift;
  
  my $width       = 128;
  my $border_char = '#';
  my $template    = sprintf "%s %%-%d.%ds %s\n", $border_char, $width-4,$width-4, $border_char;
  my $line        = $border_char x $width;
  
  warn "\n";
  warn "$line\n";
  
  $Text::Wrap::columns = $width-4;
  
  foreach my $l (@_) {
    my $lines = wrap('','', $l);
    
    warn sprintf $template;
    warn sprintf $template, $_ for split /\n/, $lines;
  }
  
  warn sprintf $template;
  warn "$line\n";
  warn "\n";
}

1;
