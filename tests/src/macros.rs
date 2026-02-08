#![expect(unused_macro_rules)]

use std::num::NonZero;

use time::{
    UtcDateTime,
    format_description::well_known::iso8601::{Config as IsoConfig, Iso8601, TimePrecision},
};

const ISO_FORMAT: Iso8601<
    {
        IsoConfig::DEFAULT
            .set_time_precision(TimePrecision::Second {
                decimal_digits: Some(NonZero::new(3).unwrap()),
            })
            .encode()
    },
> = Iso8601;

pub fn get_iso8601() -> String {
    UtcDateTime::now().format(&ISO_FORMAT).unwrap()
}

macro_rules! fmt {
    () => {};

    (@RESET_COLOR) => {
        0
    };
    (@RESET) => {
        "0;22;23;24;25;27;28;29"
    };
    (@BLACK) => {
        30
    };
    (@RED) => {
        31
    };
    (@GREEN) => {
        32
    };
    (@YELLOW) => {
        33
    };
    (@BLUE) => {
        34
    };
    (@MAGENTA) => {
        35
    };
    (@CYAN) => {
        36
    };
    (@WHITE) => {
        37
    };
    (@DEFAULT) => {
        39
    };

    (@BOLD) => {
        1
    };
    (@DIM) => {
        2
    };
    (@FAINT) => {
        fmt!(@DIM)
    };
    (@ITALIC) => {
        3
    };
    (@UNDERLINE) => {
        4
    };
    (@BLINK) => {
        5
    };
    (@REVERSE) => {
        7
    };
    (@HIDDEN) => {
        8
    };
    (@STRIKETHROUGH) => {
        9
    };

    (@$ident:ident) => {
        compile_error!(concat!("Unknown color identifier '", stringify!($ident), "'"))
    };

    ($first:ident $(, $rest:ident)*) => {
        concat!("\x1B[", fmt!(@$first) $(, ";", fmt!(@$rest))*, "m")
    };

    ($($ident:ident$(,)?)+ => $lit:literal) => {
        concat!(fmt!($($ident),+), $lit, fmt!(RESET))
    };

    ($($ident:ident$(,)?)+ => $($tt:tt)*) => {
        format!(concat!(fmt!($($ident),+), "{}", fmt!(RESET)), format_args!($($tt)*))
    }
}

macro_rules! fprint {
    () => {
        eprintln!(concat!("[{} ", fmt!(WHITE BOLD => "OUTPUT"), "]"), $crate::macros::get_iso8601())
    };
    (time = $expr:expr; $($tt:tt)*) => {
        eprintln!(concat!("[{} ", fmt!(WHITE BOLD => "OUTPUT"), "] {}"), $expr, format_args!($($tt)*))
    };
    ($($tt:tt)*) => {
        fprint!(time = $crate::macros::get_iso8601(); $($tt)*)
    };
}

macro_rules! warn {
    () => {
        eprintln!(concat!("[{} ", fmt!(YELLOW BOLD => "WARN  "), "]"), $crate::macros::get_iso8601())
    };
    (time = $expr:expr; $($tt:tt)*) => {
        eprintln!(concat!("[{} ", fmt!(YELLOW BOLD => "WARN  "), "] {}"), $expr, format_args!($($tt)*))
    };
    ($($tt:tt)*) => {
        warn!(time = $crate::macros::get_iso8601(); $($tt)*)
    };
}

macro_rules! error {
    () => {
        eprintln!(concat!("[{} ", fmt!(RED BOLD => "ERROR "), "]"), $crate::macros::get_iso8601())
    };
    (time = $expr:expr; $($tt:tt)*) => {
        eprintln!(concat!("[{} ", fmt!(RED BOLD => "ERROR "), "] {}"), $expr, format_args!($($tt)*))
    };
    ($($tt:tt)*) => {
        error!(time = $crate::macros::get_iso8601(); $($tt)*)
    };
}

macro_rules! fatal {
    () => {
        eprintln!(concat!("[{} ", fmt!(RED REVERSE BOLD => "FATAL!"), "]"), $crate::macros::get_iso8601())
    };
    (time = $expr:expr; $($tt:tt)*) => {
        eprintln!(concat!("[{} ", fmt!(RED REVERSE BOLD => "FATAL!"), "] {}"), $expr, format_args!($($tt)*))
    };
    ($($tt:tt)*) => {
        fatal!(time = $crate::macros::get_iso8601(); $($tt)*)
    };
}

macro_rules! info {
    () => {
        eprintln!(concat!("[{} ", fmt!(CYAN BOLD => "INFO  "), "]"), $crate::macros::get_iso8601())
    };
    (time = $expr:expr; $($tt:tt)*) => {
        eprintln!(concat!("[{} ", fmt!(CYAN BOLD => "INFO  "), "] {}"), $expr, format_args!($($tt)*))
    };
    ($($tt:tt)*) => {
        info!(time = $crate::macros::get_iso8601(); $($tt)*)
    };
}

macro_rules! debug {
    () => {
        eprintln!(concat!("[{} ", fmt!(MAGENTA BOLD => "DEBUG "), "]"), $crate::macros::get_iso8601())
    };
    (time = $expr:expr; $($tt:tt)*) => {
        eprintln!(concat!("[{} ", fmt!(MAGENTA BOLD => "DEBUG "), "] {}"), $expr, format_args!($($tt)*))
    };
    ($($tt:tt)*) => {
        debug!(time = $crate::macros::get_iso8601(); $($tt)*)
    };
}