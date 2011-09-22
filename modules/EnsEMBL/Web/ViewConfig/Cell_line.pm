# $Id$

package EnsEMBL::Web::ViewConfig::Cell_line;

use strict;

use JSON qw(from_json);

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
 
  my %default_evidence_types = (
    CTCF     => 1,
    DNase1   => 1,
    H3K4me3  => 1,
    H3K36me3 => 1,
    H3K27me3 => 1,
    H3K9me3  => 1,
    PolII    => 1,
    PolIII   => 1,
  );
  
  my $funcgen_tables    = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  my $cell_lines        = $funcgen_tables->{'cell_type'}{'ids'};
  my $evidence_features = $funcgen_tables->{'feature_type'}{'ids'};
  
  $self->{'feature_type_ids'}  = $funcgen_tables->{'meta'}{'feature_type_ids'};
  $self->{'type_descriptions'} = $funcgen_tables->{'feature_set'}{'analyses'}{'RegulatoryRegion'}{'desc'};
  
  my $defaults;
  
  foreach my $cell_line (keys %$cell_lines) {
    $cell_line =~ s/\:\w*//;
    
    # allow all evdience for this sell type to be configured together  
    $defaults->{"opt_cft_$cell_line:all"} = 'off';
    
    foreach my $evidence_type (keys %$evidence_features) {
      my ($evidence_name, $evidence_id) = split /\:/, $evidence_type;
      $defaults->{"opt_cft_$cell_line:$evidence_name"} = exists $default_evidence_types{$evidence_name} && exists $self->{'feature_type_ids'}{$cell_line}{$evidence_id} ? 'on' : 'off';
    }
  }
  
  foreach my $evidence_type (keys %$evidence_features) {
    $evidence_type =~ s/\:\w*//;
    $defaults->{"opt_cft_$evidence_type:all"} = 'off';
  }
  
  $self->set_defaults($defaults);
}

sub add_image_config {
  my $self = shift;
  $self->set_evidence_types(@_);
  $self->SUPER::add_image_config(@_) if $self->hub->function ne 'Cell_line';
}

sub reset {
  my $self = shift;
  $self->SUPER::reset(@_);
  $self->set_evidence_types(@_);
}

sub set_evidence_types {
  my ($self, $image_config) = @_;
  my $tree = (ref $image_config ? $image_config : $self->hub->get_imageconfig($image_config))->tree;
  
  foreach my $type (qw(core other)) {
    my $node = $tree->get_node('regulatory_features');
    
    $self->{"${type}_evidence_types"} = [];
    
    next unless $node;
    
    foreach (grep $_->get('type') eq $type, $node->nodes) {
      push @{$self->{"${type}_evidence_types"}}, { cell_line => [split '_', $_->id]->[-1], display => $_->get('display') };
      $self->{'renderers'} ||= $_->get('renderers');
    }
  }
}

sub form {
  my $self = shift;
  
  if ($self->hub->function eq 'Cell_line') {
    $self->form_evidence_types;
  } elsif ($self->can('form_context')) {
    $self->form_context;
  }
}

sub build_imageconfig_form {
  my $self         = shift;
  my $image_config = shift;
  my $hub          = $self->hub;
  my $tree         = $self->tree;
  my %counts;
  
  $self->SUPER::build_imageconfig_form($image_config);
  
  my $menu = $tree->get_node('regulatory_features');
  
  return unless $menu;
  
  foreach (qw(core other)) {
    $counts{$_}{'total'} = scalar @{$self->{"${_}_evidence_types"}};
    $counts{$_}{'on'}    = scalar grep { $_->{'display'} ne 'off' } @{$self->{"${_}_evidence_types"}}; 
  }
  
  $menu->after($tree->create_node('regulatory_evidence_core', {
    url          => $hub->url('Config', { function => 'Cell_line', partial => 1, set => 'core' }),
    availability => 1,
    caption      => 'Open chromatin & TFBS',
    class        => 'Regulatory_evidence_core',
    li_class     => 'overflow',
    count        => qq{(<span class="on">$counts{'core'}{'on'}</span>/$counts{'core'}{'total'})}
  }))->after($tree->create_node('regulatory_evidence_other', {
    url          => $hub->url('Config', { function => 'Cell_line', partial => 1, set => 'other' }),
    availability => 1,
    caption      => 'Histones & polymerases',
    class        => 'Regulatory_evidence_other',
    li_class     => 'overflow',
    count        => qq{(<span class="on">$counts{'other'}{'on'}</span>/$counts{'other'}{'total'})}
  }));
}

sub form_evidence_types {
  my $self          = shift;
  my $hub           = $self->hub;
  my $set           = $hub->param('set');
  my $adaptor       = $hub->get_adaptor('get_FeatureTypeAdaptor', 'funcgen');
  my %renderers     = @{$self->{'renderers'}};
  my $img_url       = $self->img_url;
  my @feature_types = map { sort { $a->name cmp $b->name } @{$adaptor->fetch_all_by_class($_)} } $set eq 'core' ? ('Open Chromatin', 'Transcription Factor') : qw(Polymerase Histone);
  my %filters       = ( '' => 'All classes' );
  my @columns       = @{$self->{"${set}_evidence_types"}};
  my $width         = (scalar @columns * 26) + 91; # Each td is 25px wide + 1px border. The first cell (th) is 90px + 1px border
  my $selected      = qq{<img class="tick" src="${img_url}tick.png" alt="Selected" title="Selected" /><span class="current">};
  my (@rows, $rows_html, @headers_html, $last_class);
  
  $self->{'panel_type'} = 'FuncgenMatrix';
  
  my $select_all_col = qq{
    <div class="select_all_column floating_popup">
      Select features for %s<br />
      <div><input type="radio" name="%s" class="default">Default</input></div>
      <div><input type="radio" name="%s" class="all">All</input></div>
      <div><input type="radio" name="%s" class="none">None</input></div>
    </div>
  };
  
  my $select_all_row = qq{
    <div class="select_all_row floating_popup">
      Select all<br />
      %s
      <input type="checkbox" />
    </div>
  };
  
  my ($k, $v);
  my $renderer_html = qq{<ul class="popup_menu"><li class="header">Change track style<img class="close" src="${img_url}close.png" title="Close" alt="Close" /></li>};
  $renderer_html   .= qq{<li class="$k"><img title="$v" alt="$v" src="${img_url}render/$k.gif" class="Regulatory_evidence_$set" /><span>$v</span></li>} while ($k, $v) = splice @{$self->{'renderers'}}, 0, 2;
  $renderer_html   .= '</ul>';
  $headers_html[1]  = $renderer_html;
  
  foreach (@feature_types) {
    my $feature_name = $_->name;
    my $feature_id   = $_->dbID;
    my $class        = $_->class;
    (my $cls         = lc $class) =~ s/ /_/g;
    my @row          = ("$feature_name $cls", { tag => 'th', class => 'first', html => sprintf("$feature_name$select_all_row", $feature_name) });
    my $exists;
    
    push @rows, [ 'gap', { tag => 'td' }] if $last_class && $class ne $last_class;
    
    $last_class    = $class;
    $filters{$cls} = $class;
    
    foreach (@columns) {
      my $cell_line = $_->{'cell_line'};
      my $cell      = { tag => 'td', html => '<p></p>' };
      
      if (exists $self->{'feature_type_ids'}{$cell_line}{$feature_id}) {
        $cell->{'title'}  = "$cell_line:$feature_name";
        $cell->{'class'}  = "option $cell_line $feature_name";
        $cell->{'class'} .= ' on'      if $self->get("opt_cft_$cell_line:$feature_name") eq 'on';
        $cell->{'class'} .= ' default' if $self->{'options'}{"opt_cft_$cell_line:$feature_name"}{'default'} eq 'on';
        
        $exists = 1;
      } else {
        $cell->{'class'} = 'disabled';
      }
      
      push @row, $cell;
    }
    
    push @rows, \@row if $exists;
  }
    
  foreach (@rows) {
    my $row_class = shift @$_;
    my $row_html;
    
    foreach (@$_) {
      $row_html .= sprintf('<%s%s%s%s>%s</%s>',
        $_->{'tag'},
        $_->{'class'}   ? qq{ class="$_->{'class'}"}     : '',
        $_->{'title'}   ? qq{ title="$_->{'title'}"}     : '',
        $_->{'colspan'} ? qq{ colspan="$_->{'colspan'}"} : '',
        $_->{'html'},
        $_->{'tag'}
      );
    }
    
    $rows_html .= qq{<tr class="$row_class">$row_html</tr>};
  }
  
  foreach (@columns) {
    my $c     = $_->{'cell_line'};
    my $d     = $_->{'display'};
    (my $menu = $renderer_html) =~ s/(<li class="$d">.+?)<span>(.+?<\/li>)/$1$selected$2/;
    
    $headers_html[0] .= sprintf qq{<th class="$c"><p>$c</p>$select_all_col</th>}, $c, $c, $c, $c;
    $headers_html[2] .= qq{
      <th class="$c reg_feats_${set}_$c">
        <img class="menu_option" title="$renderers{$d}" alt="$renderers{$d}" src="${img_url}render/$d.gif">
        <input type="hidden" class="track_name" name="reg_feats_${set}_$c" value="$d">
        $menu
      </th>
    };
  }
  
  my $html = sprintf('
    <h1>Regulation</h1>
    <div class="header_wrapper">
      <h2>%s</h2>
      <div class="help" title="Click for more information"></div>
      <div class="desc">%s</div>
    </div>
    <div class="filter_wrapper">
      <h2>Filter by</h2>
      <select class="filter">%s</select>
      <input type="text" class="filter" value="Enter cell or evidence types" />
    </div>
    <div class="matrix_key">
      <h2>Key</h2>
      <div class="key"><div>On</div><div class="cell on"></div></div>
      <div class="key"><div>Off</div><div class="cell off"></div></div>
      <div class="key"><div>Unavailable</div><div class="cell disabled"></div></div>
    </div>
    <div style="width:%spx">
      <table class="funcgen_matrix" cellspacing="0" cellpadding="0">
        <thead>
          <tr><th class="first"></th>%s</tr>
          <tr class="renderers"><th class="first select_all"><div class="menu_option"><h2>Track style:</h2><em>Enable/disable all</em></div>%s</th>%s</tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
    </div>
    <div class="no_results">No results found</div>
    ',
    $set eq 'core' ? 'Open chromatin &amp; Transcription Factor Binding Sites' : 'Histones &amp; Polymerases',
    $self->{'type_descriptions'}{$set},
    join('', map qq{<option value="$_">$filters{$_}</option>}, sort keys %filters),
    $width,
    @headers_html,
    $rows_html
  );
  
  $self->get_form->append_children(
    [ 'div', { inner_HTML => $html, class => 'js_panel funcgen_matrix', id => "funcgen_matrix_$set" }]
  );
}

1;
