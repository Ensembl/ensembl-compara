package EnsEMBL::Web::TextSequence::Output::Web;

use strict;
use warnings;

use base qw(EnsEMBL::Web::TextSequence::Output);

use JSON qw(to_json);
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Utils::RandomString qw(random_string);

use EnsEMBL::Web::TextSequence::Output::Web::Adorn;

sub reset {
  my $self = shift;
  $self->SUPER::reset(@_);
  $self->{'adorn'} = EnsEMBL::Web::TextSequence::Output::Web::Adorn->new;
}

sub make_layout {
  my ($self,$config) = @_;

  return EnsEMBL::Web::TextSequence::Layout::String->new([
    { key => 'pre' },
    {
      if => 'number',
      then => [
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'} },
        { key => 'start', width => $config->{'padding'}{'number'} },
        { post => ' ' },
      ]
    },
    { 
      key => ['adid','letters'], width => {
        letters => -$config->{'display_width'}
      },
      fmt => '<span class="adorn adorn-%s _seq">%s</span>',
    },
    {
      if => 'number',
      then => [
        { post => ' ' },
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'} },
        { key => 'start', width => $config->{'padding'}{'number'} },
      ]
    },
    { key => ['adid','post'], fmt => '<span class="ad-post-%s">%s</span>' },
    { post => "\n" },
    { if => 'vskip', then => [ { post => "\n" }] },
  ]);
}

sub final_wrapper {
  return sprintf($_[0]->template,$_[1]);
}

sub add_line {
  my ($self,$line,$markup,$config) = @_;

  my $letters = "";
  my $idx = 0;
  foreach my $m (@$markup) {
    $letters .= ($m->{'letter'}||' ');
    my @classes = split(' ',$m->{'class'}||'');
    my $style = $self->c2s->convert_class_to_style(\@classes,$config);
    $self->{'adorn'}->adorn($line->line_num,$idx,'style',$style||'');
    $self->{'adorn'}->adorn($line->line_num,$idx,'title',$m->{'title'}||'');
    $self->{'adorn'}->adorn($line->line_num,$idx,'href',$m->{'href'}||'');
    $self->{'adorn'}->adorn($line->line_num,$idx,'tag',$m->{'tag'}||'');
    $self->{'adorn'}->adorn($line->line_num,$idx,'letter',$m->{'new_letter'}||'');
    $idx++;
  }

  push @{$self->{'data'}[$line->seq->id]},{
    line => $letters,
    length => length $letters,
    pre => $line->pre,
    post => $line->post,
    adid => $line->line_num
  };

  $self->{'adorn'}->flourish('post',$line->line_num,$line->post) if $line->post;
}

sub continue_url {
  my ($self,$url) = @_; 

  my ($path,$params) = split(/\?/,$url,2);
  my @params = split(/;/,$params);
  for(@params) { $_ = 'adorn=only' if /^adorn=/; }
  return $path.'?'.join(';',@params,'adorn=only');
}

sub output_data {
  my ($self) = @_; 

  my $out = { 
    %{$self->{'adorn'}->adorn_data},
    %{$self->{'legend'}}
  };  
  if($self->{'more'}) {
    $out = { 
      url => $self->continue_url($self->{'more'}),
      provisional => $out
    };  
  }
  return $out;
}

sub output_legend { # May be overriden in sublcasses
  my ($self,$config) = @_;

  return qq(<div class="_adornment_key adornment-key"></div>);
}

sub build_output {
  my ($self,$config,$line_numbers,$multi,$id) = @_;

  my $layout = $self->make_layout($config);
  my $html = $self->format_lines($layout,$config,$line_numbers,$multi);
  $html = $self->final_wrapper($html->emit);
  my $adornment = $self->output_data;
  my $adornment_json = encode_entities(to_json($adornment),"<>");
  my $key_html = $self->output_legend($config);
  if($self->view->phase==2) {
    return
      qq(<div><span class="adornment-data">$adornment_json</span></div>);
  } else {
    return $self->_panel($key_html,$html,$adornment_json,$id);
  }
}

sub _panel {
  my ($self,$key,$output,$adornment,$id) = @_; 

  my $random_id = random_string(8);

  return qq( 
    <div class="js_panel" id="$random_id">
      $key
      <div class="adornment">
        <span class="adornment-data" style="display:none;">
          $adornment
        </span>
        $output
      </div>
      <input type="hidden" class="panel_type" value="TextSequence"
             name="panel_type_$id" />
    </div>
  );
}

1;
