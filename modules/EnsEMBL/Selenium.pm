=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Selenium;

### An Ensembl-specific wrapper around Test::WWW::Selenium, to make it easier
### to deal with our Ajax pages

use strict;
use Test::More;
use Try::Tiny;
use base 'Test::WWW::Selenium';

# return user defined timeout, or a default
sub _timeout {  return $_[0]->{_timeout} || 50000 }

sub ensembl_wait_for_ajax {
### Wait until there are no ajax loading indicators or errors shown in the page
### Loading indicators are only shown if loading takes >500ms, so we need to pause 
### before we start checking
### TODO Make ajax check when there are multiple ajax requests
### @param timeout Integer - Apache timeout
### @param pause Integer - time to wait for spinners
  my ($self, $timeout, $pause) = @_;
  my $url = $self->get_location();
  
  $timeout ||= $self->_timeout;
  $pause   ||= 500;
  ## increase the pause and timeout if we are testing mirrors since the site is slower.
  $pause += 3000 if ($url =~ /staging|uswest|useast|ec2/);
  $timeout += 20000 if ($url =~ /staging|uswest|useast|ec2/);

  $self->pause($pause);

  my $error = try {  
                    $self->wait_for_condition(
                      qq/var \$ = selenium.browserbot.getCurrentWindow().jQuery;
                      !(\$(".ajax_load").length || \$(".ajax_error").length || \$(".syntax-error").length)/,
                    $timeout || $self->_timeout
                    );}
                catch { ['fail', "AJAX load failed"]; };
  return ($error == 1 || $error =~ /^OK/) ? ['pass', "AJAX load OK"] : $error;
  return $error; 
}

sub ensembl_wait_for_element {
### Wait for an element to be present, e.g. if Javascript controlled
  my ($self, $locator, $timeout) = @_;
  my $url = $self->get_location();
  my $real_error;
 
  $timeout ||= $self->_timeout;
  $timeout += 20000 if ($url =~ /staging|uswest|useast|ec2/);

  my $error = try { $self->wait_for_element_present($locator, $timeout) }
              catch { "ELEMENT $locator NOT FOUND"; }
              finally { if (@_) { $real_error = join(' ', @_); } };
  $error .= "\n$real_error";

  return ($error == 1 || $error =~ /^OK/) ? ['pass', "Element $locator found"] : ['fail', $error];
}

sub ensembl_wait_for_page_to_load {
### Wait for a 200 OK response, then wait until all ajax has loaded
### Also, we have custom error pages, so we need to specifically check for error text 
### in the page title instead of relying on Apache HTTP codes 
  my ($self, $timeout) = @_;
  
  $timeout ||= $self->_timeout;

  my $error = try { $self->wait_for_page_to_load($timeout); }
              catch { return ['fail', 'Page load failed at '.$self->get_location];};
  return $error if $error;

  $error = try { ok($self->get_title !~ /Internal Server Error/i, 'No Internal Server Error');}
            catch { return ['fail', 'Internal Server Error at '.$self->get_location];};
  return $error if $error;

  $error = try { ok($self->get_title !~ /404 error/i, 'No 404 Error');}
            catch {return ['fail', '404 Error at '.$self->get_location];};
  return $error if $error;

  $error = try {$self->ensembl_wait_for_ajax('50000');}
            catch {return ['fail', 'Ajax load failed at '.$self->get_location];};
  return $error;
}

sub ensembl_open {
### Wrapper around standard selenium method to return useful error message 
### @param url String - URL of page to open
### @param message String [optional] - additional text for error message
### @return ArrayRef - error code plus error message
  my ($self, $url, $message) = @_;
  my $error = "Couldn't open page $url";
  $error .= ": $message" if $message; 
  
  my $error = try { $self->open($url); }
              catch { ['fail', $error]; };
  return $error == 1 ? ['pass', "Opened page $url"] : $error;
}

sub ensembl_open_zmenu {
### Open a ZMenu by title for the given imagemap panel or, if title not provided,
### will get the coords based on the area tag for the given imagemap panel 
### (id of div for class js_panel)
### e.g. $sel->ensembl_open_zmenu('contigviewtop', 'ASN2') 
### or $sel->ensembl_open_zmenu('GenomePanel')
### @param panel String - the id of the view panel for the ZMenu to be tested
### @param aread_tag String - Anything within the area tag to be tested so that 
###                  we can get the coords for the ZMenu. can be href or a class or title.
### @param track_name String - the name of the track for the ZMenu to be tested, used for 
###                  display information only in the log.
  my ($self, $panel, $area_tag, $track_name) = @_;
  my $tag = $area_tag ?  "area[$area_tag]" : 'area[href^=#vdrag]';  

  return ('pass', "  Testing ZMenu $track_name on the $panel panel") if $self->verbose;
  $self->run_script(qq/
    Ensembl.PanelManager.panels.$panel.elLk.img.one('click', function (e) {
      var coords = Ensembl.PanelManager.panels.$panel.elLk.map.find('$tag').attr('coords').split(','); 
      Ensembl.PanelManager.panels.$panel.makeZMenu(\$.extend(e, { pageX: 0, pageY: 0 }), { x: parseInt(coords[0], 10), y: parseInt(coords[1], 10) });
    }).trigger('click');
  /)
  and $self->ensembl_wait_for_ajax(undef,'7000');
}

sub ensembl_open_zmenu_at {
### Open a ZMenu by position on the given imagemap panel
### e.g. $sel->ensembl_open_zmenu_at('contigviewtop', '160,100')
### @param panel String - id of panel
### @param pos String - coordinates as 'x,y'
  my ($self, $panel, $pos) = @_;
  
  my ($x, $y) = split /,/, $pos;
  $self->run_script(qq/
    Ensembl.PanelManager.panels.$panel.one('click', function (e) {
      Ensembl.PanelManager.panels.$panel.makeZMenu(\$.extend(e, { pageX: 0, pageY: 0 }), { x: parseInt($x, 10), y: parseInt($y, 10) });
    }).trigger('click');
  /)
  and $self->ensembl_wait_for_ajax(undef,'7000');
}

sub ensembl_click {
### Overloading click function so that it returns the current url when it fails. 
### Only use this function when ensembl_click_links below does not work,
### for example when opening an AJAX panel
### @param link String - text of link to click on
### @param timeout Integer - number of milliseconds to allow
### @return ArrayRef - error code and message
  my ($self, $link, $timeout) = @_;
  my $url = $self->get_location();
    
  return $self->click("link=$link",$timeout) 
    ? ['pass', "Click on link '$link' succeeded"] : 
      ['fail', "CLICK ON LINK '$link' FAILED: URL $url"];
}

sub ensembl_click_links {
### Click links, but can only be used for link opening page, not ajax popup
### e.g. $sel->ensembl_click_links(["link=Tool","link=Human"], '5000');
### @param links ArrayRef - list of links to click
### @param timeout Integer - allowed timeout in milliseconds
  my ($self, $links, $timeout) = @_;
  return unless $links && ref($links) eq 'ARRAY';
  my $location = $self->get_location();  
  my @output;
  
  foreach my $link (@{$links}) {
    my ($locator, $timeout) = ref $link eq 'ARRAY' ? @$link : ($link, $timeout || $self->_timeout);
    my $error = try { $self->is_element_present($locator); }
                catch {['fail', "***missing*** $locator in $location \n"]; };
    if ($error) {
      push @output, $error;
    }
    else {
      $error = try { $self->click($locator) and $self->ensembl_wait_for_page_to_load($timeout);}
                catch { ['fail', "$locator FAILED in $location \n\n"]; };
      if ($error) {
        push @output, $error;
      }
      else { 
        push @output, ['pass', "Link $locator on $location checked successfully"];
      }
    } 
  }
  return @output;
}


sub ensembl_click_all_links {
### Finds all links within an element and clicks each of them
  my ($self, $div) = @_;  

  # get all the links on the page
  my $links_href = $self->get_eval(qq{
    var \$ = selenium.browserbot.getCurrentWindow().jQuery;
    \$('$div').find('a');
  });

  my @links_array = split(',',$links_href);
  my @output;

  foreach my $link (@links_array) {
    $self->pause(500);
    push @output, $self->try_link($link);
    $self->go_back();
  }
  return @output;
}

sub try_link {
  my ($self, $link, $text) = @_;
  my $location = $self->get_location();

   my $error = try { $self->open($link); }
                 catch { return ['fail', "Couldn't open page $link"]; };
   if ($self->test_fails($error)) {
     return $error;
   }
   else {
     my $title = $self->get_title;
 
     if ($title =~ /Internal Server Error/i) {
       return ['fail', "Internal Server Error at $link"];
     }
     elsif ($title =~ /404 Error/i) {
       return ['fail', "404 Error at $link"];
     }
     else {
 
       ## Check for obvious code errors
       my @barfs = ('AJAX error', 'Runtime Error');
 
       foreach (@barfs) {
         my $fail = eval { $self->is_text_present($_); };
         if ($fail) {
           return ['fail', "Page error $_ at $link"];
         }
       }
       my $link_text = $link;
       $link_text .= "($text)" if $text;
       return ['pass', "Link $link_text successful at $location"];
     }
   }
}

sub test_fails {
  warn ">>> DEPRECATED - use Test::test_fails instead";
  my ($self, $error) = @_;
  my $fail = 0;

  if ($error) {
    if (ref($error) eq 'ARRAY' && $error->[0] ne 'pass') {
      $fail = 1;
    }
    elsif ($error ne 'OK') {
      $fail = 1;
    }
  } 
  return $fail;
}

=pod
sub ensembl_click_all_links {
### Finds all links within an element and clicks each of them
### @param div String - The id or class for the container of the links
### @param skip_link ArrayRef (optional) - array of links you want to skip such as home 
### @param text String (optional) - text to look for on the pages from the link
  my ($self, $div, $skip_link, $text) = @_;  
  my $location = $self->get_location();
  my $url     = $self->{'browser_url'};

  # get all the links on the page
  my $links_href = $self->get_eval(qq{
    var \$ = selenium.browserbot.getCurrentWindow().jQuery;
    \$('$div').find('a');
  });

  my @links_array = split(',',$links_href);
  my $i = 0;
  my @output;

  foreach my $link (@links_array) {
    $self->pause(500);
    
    # get the text for each link, use link_text to click link if there is no id to the links
    my $link_text = $self->get_eval(qq{
      \var \$ = selenium.browserbot.getCurrentWindow().jQuery; 
      \$('$div').find('a:eq($i)').text();
    });
    
    # get id for the links
    my $link_id = $self->get_eval(qq{
      \var \$ = selenium.browserbot.getCurrentWindow().jQuery; 
      \$('$div').find('a:eq($i)').attr('id');
    });    
    
    #see if link is external
    my $rel = $self->get_eval(qq{
      \var \$ = selenium.browserbot.getCurrentWindow().jQuery; 
      \$('$div').find('a:eq($i)').attr('rel');
    });
    
    $i++;
    next if grep (/$link_text/, @$skip_link);
  
    if ($rel eq 'external' || $link !~ /^$url/) {
      my $error = try { $self->open($link); }
                    catch { return ['fail', "Couldn't open page $link"]; };
      if ($error && ref($error) eq 'ARRAY' && $error->[0] eq 'fail') { 
        push @output, $error;
      }
      else {

        $error = try { ok($self->get_title !~ /Internal Server Error/i, 'No Internal Server Error');}
                  catch { return ['fail', "Internal Server Error at $location"];};
        if ($error) {
          push @output, $error;
          next;
        }

        $error = try { ok($self->get_title !~ /404 Error/i, 'No 404 Error');}
                  catch { return ['fail', "404 Error at $location"];};
        if ($error) {
          push @output, $error;
          next;
        }

        push @output, ['pass', "Link $link_text ($link) successful at $location"];
      }
    } elsif ($link_id && $link_id ne 'null') {
      push @output, $self->ensembl_click_links(["id=$link_id"]);
    } elsif ($link_text) {
      push @output, $self->ensembl_click_links(["link=$link_text"]);
    } else {
      push @output, ['fail', "LINK UNTESTED:: $link has no id or text at $location"];
      next;
    }
    
    push @output, $self->ensembl_is_text_present($text) if ($text);
    $self->go_back();
  }
  return @output;
}
=cut

sub ensembl_images_loaded {
### Check if all the ajax images on the page have been loaded successfully
  my ($self) = @_;
       
  $self->run_script(qq{
    var complete = 0;
     jQuery('img.imagemap').each(function () {
       if (this.complete) {
         complete++;
       }
     });
     if (complete === jQuery('img.imagemap').length) {
       jQuery('body').append("<p>All images loaded successfully</p>");
     }
  });
  my $location = $self->get_location();
  my $test_text = $self->ensembl_is_text_present("All images loaded successfully");
  return $test_text ? ('pass', 'Images loaded successfully') : ('fail', "IMAGE LOADING ERROR");
}


sub ensembl_is_text_present {
### Wrapper around standard selenium method to return useful error message 
  my ($self, $text) = @_;
  my $url = $self->get_location();
  
  my $error = try { $self->is_text_present($text); }
              catch { ['fail', "MISSING TEXT $text at URL $url"]; }; 
  ## $error is set to 1 if test succeeds
  return $error == 1 ? ['pass', "Text $text found at URL $url"] : $error;
}

sub ensembl_type {
### Wrapper around standard selenium method to return useful error message 
  my ($self, $locator, $text) = @_;
  my $url = $self->get_location();
  my $real_error;
 
  my $error = try { $self->type($locator, $text) }
              catch { "Failure to input text $text at URL $url"; }
              finally { if (@_) { $real_error = join(' ', @_); } };
  $error .= "\n$real_error";

  return ($error == 1 || $error =~ /^OK/) ? ['pass', "Input text $text"] : ['fail', $error];
}

sub ensembl_select {
### Wrapper around standard selenium method to return useful error message 
  my ($self, $locator, $value) = @_;
  my $url = $self->get_location();
  my $real_error;
  
  my $error = try { $self->select($locator, $value) }
              catch { "Failure to select value $value at URL $url"; }
              finally { if (@_) { $real_error = join(' ', @_); } };
  $error .= "\n$real_error";

  return ($error == 1 || $error =~ /^OK/) ? ['pass', "Selected value $value in dropdown"] : ['fail', $error];
}

sub ensembl_submit {
### Wrapper around standard selenium method to return useful error message 
  my ($self, $locator) = @_;
  my $url = $self->get_location();
  my $real_error;
  
  my $error = try { $self->submit($locator) }
              catch { "Form submission failure at URL $url"; } 
              finally { if (@_) { $real_error = join(' ', @_); } };
  $error .= "\n$real_error";

  return ($error == 1 || $error =~ /^OK/) ? ['pass', "Form $locator submitted"] : ['fail', $error];
}

1;
