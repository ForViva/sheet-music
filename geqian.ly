\version "2.20.0"
#(set-global-staff-size 20)

% un-comment the next line to remove Lilypond tagline:
% \header { tagline="" }

% comment out the next line if you're debugging jianpu-ly
% (but best leave it un-commented in production, since
% the point-and-click locations won't go to the user input)
\pointAndClickOff

\paper {
  print-all-headers = ##t %% allow per-score headers

  % un-comment the next line for A5:
  % #(set-default-paper-size "a5" )

  % un-comment the next line for no page numbers:
  % print-page-number = ##f

  % un-comment the next 3 lines for a binding edge:
  % two-sided = ##t
  % inner-margin = 20\mm
  % outer-margin = 10\mm

  % un-comment the next line for a more space-saving header layout:
  % scoreTitleMarkup = \markup { \center-column { \fill-line { \magnify #1.5 { \bold { \fromproperty #'header:dedication } } \magnify #1.5 { \bold { \fromproperty #'header:title } } \fromproperty #'header:composer } \fill-line { \fromproperty #'header:instrument \fromproperty #'header:subtitle \smaller{\fromproperty #'header:subsubtitle } } } }

  % As jianpu-ly was run on a Mac, we include a Mac fonts workaround.
  % The Mac version of Lilypond 2.18 used Arial Unicode MS as a
  % fallback even in the Serif font, but 2.20 drops this in Serif
  % (using it only in Sans), which means any Serif text (titles,
  % lyrics etc) that includes Chinese will likely fall back to
  % Japanese fonts which don't support all Simplified hanzi.
  % This brings back 2.18's behaviour on 2.20+:
  #(define fonts
    (set-global-fonts
     #:roman "Source Serif Pro,Source Han Serif SC,Times New Roman,Arial Unicode MS"
     #:factor (/ staff-height pt 20)
    ))
}

%% 2-dot and 3-dot articulations
#(append! default-script-alist
   (list
    `(two-dots
       . (
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold ":" #})
           (padding . 0.20)
           (avoid-slur . inside)
           (direction . ,UP)))))
#(append! default-script-alist
   (list
    `(three-dots
       . (
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold "⋮" #})
           (padding . 0.30)
           (avoid-slur . inside)
           (direction . ,UP)))))
"two-dots" =
#(make-articulation 'two-dots)

"three-dots" =
#(make-articulation 'three-dots)

\layout {
  \context {
    \Score
    scriptDefinitions = #default-script-alist
  }
}

note-mod =
#(define-music-function
     (text note)
     (markup? ly:music?)
   #{
     \tweak NoteHead.stencil #ly:text-interface::print
     \tweak NoteHead.text
        \markup \lower #0.5 \sans \bold #text
     #note
   #})
#(define (flip-beams grob)
   (ly:grob-set-property!
    grob 'stencil
    (ly:stencil-translate
     (let* ((stl (ly:grob-property grob 'stencil))
            (centered-stl (ly:stencil-aligned-to stl Y DOWN)))
       (ly:stencil-translate-axis
        (ly:stencil-scale centered-stl 1 -1)
        (* (- (car (ly:stencil-extent stl Y)) (car (ly:stencil-extent centered-stl Y))) 0) Y))
     (cons 0 -0.8))))

%=======================================================
#(define-event-class 'jianpu-grace-curve-event 'span-event)

#(define (add-grob-definition grob-name grob-entry)
   (set! all-grob-descriptions
         (cons ((@@ (lily) completize-grob-entry)
                (cons grob-name grob-entry))
               all-grob-descriptions)))

#(define (jianpu-grace-curve-stencil grob)
   (let* ((elts (ly:grob-object grob 'elements))
          (refp-X (ly:grob-common-refpoint-of-array grob elts X))
          (X-ext (ly:relative-group-extent elts refp-X X))
          (refp-Y (ly:grob-common-refpoint-of-array grob elts Y))
          (Y-ext (ly:relative-group-extent elts refp-Y Y))
          (direction (ly:grob-property grob 'direction RIGHT))
          (x-start (* 0.5 (+ (car X-ext) (cdr X-ext))))
          (y-start (+ (car Y-ext) 0.32))
          (x-start2 (if (eq? direction RIGHT)(+ x-start 0.5)(- x-start 0.5)))
          (x-end (if (eq? direction RIGHT)(+ (cdr X-ext) 0.2)(- (car X-ext) 0.2)))
          (y-end (- y-start 0.5))
          (stil (ly:make-stencil `(path 0.1
                                        (moveto ,x-start ,y-start
                                         curveto ,x-start ,y-end ,x-start ,y-end ,x-start2 ,y-end
                                         lineto ,x-end ,y-end))
                                  X-ext
                                  Y-ext))
          (offset (ly:grob-relative-coordinate grob refp-X X)))
     (ly:stencil-translate-axis stil (- offset) X)))

#(add-grob-definition
  'JianpuGraceCurve
  `(
     (stencil . ,jianpu-grace-curve-stencil)
     (meta . ((class . Spanner)
              (interfaces . ())))))

#(define jianpu-grace-curve-types
   '(
      (JianpuGraceCurveEvent
       . ((description . "Used to signal where curve encompassing music start and stop.")
          (types . (general-music jianpu-grace-curve-event span-event event))
          ))
      ))

#(set!
  jianpu-grace-curve-types
  (map (lambda (x)
         (set-object-property! (car x)
           'music-description
           (cdr (assq 'description (cdr x))))
         (let ((lst (cdr x)))
           (set! lst (assoc-set! lst 'name (car x)))
           (set! lst (assq-remove! lst 'description))
           (hashq-set! music-name-to-property-table (car x) lst)
           (cons (car x) lst)))
    jianpu-grace-curve-types))

#(set! music-descriptions
       (append jianpu-grace-curve-types music-descriptions))

#(set! music-descriptions
       (sort music-descriptions alist<?))


#(define (add-bound-item spanner item)
   (if (null? (ly:spanner-bound spanner LEFT))
       (ly:spanner-set-bound! spanner LEFT item)
       (ly:spanner-set-bound! spanner RIGHT item)))

jianpuGraceCurveEngraver =
#(lambda (context)
   (let ((span '())
         (finished '())
         (current-event '())
         (event-start '())
         (event-stop '()))
     
     `((listeners
        (jianpu-grace-curve-event .
          ,(lambda (engraver event)
             (if (= START (ly:event-property event 'span-direction))
                 (set! event-start event)
                 (set! event-stop event)))))
       
       (acknowledgers
        (note-column-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)
                  (add-bound-item span grob)))
             (if (ly:spanner? finished)
                 (begin
                  (ly:pointer-group-interface::add-grob finished 'elements grob)
                  (add-bound-item finished grob)))))
        
        (inline-accidental-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)))
             (if (ly:spanner? finished)
                 (ly:pointer-group-interface::add-grob finished 'elements grob))))
        
        (script-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)))
             (if (ly:spanner? finished)
                 (ly:pointer-group-interface::add-grob finished 'elements grob))))
        
        ;; add additional interfaces to acknowledge here
        )
       
       (process-music .
         ,(lambda (trans)
            (if (ly:stream-event? event-stop)
                (if (null? span)
                    (ly:warning "No start to this curve.")
                    (begin
                     (set! finished span)
                     (ly:engraver-announce-end-grob trans finished event-start)
                     (set! span '())
                     (set! event-stop '()))))
            (if (ly:stream-event? event-start)
                (begin
                 (set! span (ly:engraver-make-grob trans 'JianpuGraceCurve event-start))
                 (set! event-start '())))))
       
       (stop-translation-timestep .
         ,(lambda (trans)
            (if (and (ly:spanner? span)
                     (null? (ly:spanner-bound span LEFT)))
                (ly:spanner-set-bound! span LEFT
                  (ly:context-property context 'currentMusicalColumn)))
            (if (ly:spanner? finished)
                (begin
                 (if (null? (ly:spanner-bound finished RIGHT))
                     (ly:spanner-set-bound! finished RIGHT
                       (ly:context-property context 'currentMusicalColumn)))
                 (set! finished '())
                 (set! event-start '())
                 (set! event-stop '())))))
       
       (finalize
        (lambda (trans)
          (if (ly:spanner? finished)
              (begin
               (if (null? (ly:spanner-bound finished RIGHT))
                   (set! (ly:spanner-bound finished RIGHT)
                         (ly:context-property context 'currentMusicalColumn)))
               (set! finished '())))
          (if (ly:spanner? span)
              (begin
               (ly:warning "unterminated curve :-(")
               (ly:grob-suicide! span)
               (set! span '()))))))))

jianpuGraceCurveStart =
#(make-span-event 'JianpuGraceCurveEvent START)

jianpuGraceCurveEnd =
#(make-span-event 'JianpuGraceCurveEvent STOP)
%===========================================================

%{ The jianpu-ly input was:
%% tempo: 4=60
title=搁浅
1=E
4/4

WithStaff

0 0 q0 q3 q5. s2'
q1' q4 q4 s3 s3 ~ s3 q2. q7 q1'
q2' q5 q5 s4 s4 ~ s4 q3. s3 ( s4 ) q5
q5 g[5] s6 s1 ~ q1. s6 q6 q7 q5 q2
q4 q3 g[2] q3 q3 ~ q3 q3 q5. s2'
q1' q4 q4 s3 s3 ~ s3 q2. q7 q1'
q2' q2' q2' s7 s2' ~ s2' q1' ~ s1' q6 q7
g[7] q1' s7 g[7] s1' ~ q1'. s7 q6 q7 g[7] q1' s7 g[7] s1'
~ 1' - 0 0
%}


\score {
<< \override Score.BarNumber.break-visibility = #center-visible
\override Score.BarNumber.Y-offset = -1
\set Score.barNumberVisibility = #(every-nth-bar-number-visible 5)

%% === BEGIN JIANPU STAFF ===
    \new RhythmicStaff \with {
    \consists "Accidental_engraver" 
   %% Limit space between Jianpu and corresponding-Western staff
   \override VerticalAxisGroup.staff-staff-spacing = #'((minimum-distance . 7) (basic-distance . 7) (stretchability . 0))

    % Get rid of the stave but not the barlines:
    \override StaffSymbol.line-count = #0 % tested in 2.15.40, 2.16.2, 2.18.0, 2.18.2, 2.20.0 and 2.22.2
    \override BarLine.bar-extent = #'(-2 . 2) % LilyPond 2.18: please make barlines as high as the time signature even though we're on a RhythmicStaff (2.16 and 2.15 don't need this although its presence doesn't hurt; Issue 3685 seems to indicate they'll fix it post-2.18)
    $(add-grace-property 'Voice 'Stem 'direction DOWN)
    $(add-grace-property 'Voice 'Slur 'direction UP)
    $(add-grace-property 'Voice 'Stem 'length-fraction 0.5)
    $(add-grace-property 'Voice 'Beam 'beam-thickness 0.1)
    $(add-grace-property 'Voice 'Beam 'length-fraction 0.3)
    $(add-grace-property 'Voice 'Beam 'after-line-breaking flip-beams)
    $(add-grace-property 'Voice 'Beam 'Y-offset 2.5)
    $(add-grace-property 'Voice 'NoteHead 'Y-offset 2.5)
    }
    { \new Voice="W" {
    \override Beam.transparent = ##f
    \override Stem.direction = #DOWN
    \override Tie.staff-position = #2.5
    \tupletUp
    \override Stem.length-fraction = #0.5
    \override Beam.beam-thickness = #0.1
    \override Beam.length-fraction = #0.5
    \override Beam.after-line-breaking = #flip-beams
    \override Voice.Rest.style = #'neomensural % this size tends to line up better (we'll override the appearance anyway)
    \override Accidental.font-size = #-4
    \override TupletBracket.bracket-visibility = ##t
\set Voice.chordChanges = ##t %% 2.19 bug workaround

    \override Staff.TimeSignature.style = #'numbered
    \override Staff.Stem.transparent = ##t
     \tempo 4=60 \mark \markup{1=E} \time 4/4  \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.]
| %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "4" f'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
~ \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
| %{ bar 3: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "4" f'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f'16]
~ \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "4" f'16[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f'16
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
| %{ bar 4: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\grace { \jianpuGraceCurveStart s16 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16] }
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
~ \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "7" b'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\grace { \jianpuGraceCurveStart s16 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16] }
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
~ \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.]
| %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "4" f'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
~ \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
| %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "7" b'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.]
~ \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.
~ \set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "7" b'8]
\grace { \jianpuGraceCurveStart s16 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "7" b'16] }
| %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "7" b'16
\grace { \jianpuGraceCurveStart s16 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "7" b'16] }
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
~ \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8.^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "7" b'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "7" b'8]
\grace { \jianpuGraceCurveStart s16 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "7" b'16] }
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "7" b'16
\grace { \jianpuGraceCurveStart s16 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "7" b'16] }
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
~ | %{ bar 9: %}
 \note-mod "1" c''4^.
 \note-mod "–" c''4  \note-mod "0" r4  \note-mod "0" r4 \bar "|." } }
% === END JIANPU STAFF ===


%% === BEGIN 5-LINE STAFF ===
    \new Staff {
    \override Score.SystemStartBar.collapse-height = #11 % (needed on 2.22)
    \new Voice="X" {
    #(set-accidental-style 'modern-cautionary)
    \override Staff.TimeSignature.style = #'numbered
    \set Voice.chordChanges = ##f % for 2.19.82 bug workaround
 \tempo 4=60 \transpose c e { \key c \major  \time 4/4 r2 r8 e'8 g'8. d''16 | %{ bar 2: %} c''8 f'8 f'8 e'16 e'16 ~ e'16 d'8. b'8 c''8 | %{ bar 3: %} d''8 g'8 g'8 f'16 f'16 ~ f'16 e'8. e'16 ( f'16 ) g'8 | %{ bar 4: %} g'8 \grace { g'16 } a'16 c'16 ~ c'8. a'16 a'8 b'8 g'8 d'8 | %{ bar 5: %} f'8 e'8 \grace { d'16 } e'8 e'8 ~ e'8 e'8 g'8. d''16 | %{ bar 6: %} c''8 f'8 f'8 e'16 e'16 ~ e'16 d'8. b'8 c''8 | %{ bar 7: %} d''8 d''8 d''8 b'16 d''16 ~ d''16 c''8 ~ c''16 a'8 b'8 \grace { b'16 } | %{ bar 8: %} c''8 b'16 \grace { b'16 } c''16 ~ c''8. b'16 a'8 b'8 \grace { b'16 } c''8 b'16 \grace { b'16 } c''16 ~ | %{ bar 9: %} c''2 r2 } } }
% === END 5-LINE STAFF ===

>>
\header{
title="搁浅"
}
\layout{
  \context {
    \Global
    \grobdescriptions #all-grob-descriptions
  }
  \context {
    \Score
    \consists \jianpuGraceCurveEngraver % for spans
  }
} }
\score {
\unfoldRepeats
<< 

% === BEGIN MIDI STAFF ===
    \new Staff { \new Voice="Y" { \tempo 4=60 \transpose c e { \key c \major  \time 4/4 r2 r8 e'8 g'8. d''16 | %{ bar 2: %} c''8 f'8 f'8 e'16 e'16 ~ e'16 d'8. b'8 c''8 | %{ bar 3: %} d''8 g'8 g'8 f'16 f'16 ~ f'16 e'8. e'16 ( f'16 ) g'8 | %{ bar 4: %} g'8 \grace { g'16 } a'16 c'16 ~ c'8. a'16 a'8 b'8 g'8 d'8 | %{ bar 5: %} f'8 e'8 \grace { d'16 } e'8 e'8 ~ e'8 e'8 g'8. d''16 | %{ bar 6: %} c''8 f'8 f'8 e'16 e'16 ~ e'16 d'8. b'8 c''8 | %{ bar 7: %} d''8 d''8 d''8 b'16 d''16 ~ d''16 c''8 ~ c''16 a'8 b'8 \grace { b'16 } | %{ bar 8: %} c''8 b'16 \grace { b'16 } c''16 ~ c''8. b'16 a'8 b'8 \grace { b'16 } c''8 b'16 \grace { b'16 } c''16 ~ | %{ bar 9: %} c''2 r2 } } }
% === END MIDI STAFF ===

>>
\header{
title="搁浅"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
