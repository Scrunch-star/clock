module test_clock(
    input clk,
    input rst_n,
    input pill_pulse,
    input start,
    input stop,
    input bottle_ok,
    input [3:0] sw_target_ones,
    input [3:0] sw_target_tens,
    input sw_mode_limit,
    input sw_auto_move,
    output reg [6:0] seg_state,
    output [3:0] lg2_pill_ones,
    output [3:0] lg3_pill_tens,
    output [3:0] lg4_bot_ones,
    output [3:0] lg5_bot_tens,
    output [3:0] lg6_bot_hund,
    output alarm
);

    reg start_s, stop_s, pulse_s, bottle_s;
    reg start_d, stop_d, pulse_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_s <= 1'b0;
            stop_s <= 1'b0;
            pulse_s <= 1'b0;
            bottle_s <= 1'b0;
        end else begin
            start_s <= start;
            stop_s <= stop;
            pulse_s <= pill_pulse;
            bottle_s <= bottle_ok;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d <= 1'b0;
            stop_d <= 1'b0;
            pulse_d <= 1'b0;
        end else begin
            start_d <= start_s;
            stop_d <= stop_s;
            pulse_d <= pulse_s;
        end
    end

    wire start_rise = start_s & ~start_d;
    wire stop_rise  = stop_s & ~stop_d;
    wire pulse_rise = pulse_s & ~pulse_d;

    reg [15:0] div_cnt;
    reg tick_1hz;
    reg blink;
    wire [15:0] div_max = sw_auto_move ? 16'd100 : 16'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 16'd0;
            tick_1hz <= 1'b0;
            blink <= 1'b0;
        end else begin
            if (div_cnt == (div_max - 16'd1)) begin
                div_cnt <= 16'd0;
                tick_1hz <= 1'b1;
                blink <= ~blink;
            end else begin
                div_cnt <= div_cnt + 16'd1;
                tick_1hz <= 1'b0;
            end
        end
    end

    reg set_mode;
    reg [1:0] sel;
    reg run_en;

    reg [3:0] hour_tens, hour_ones;
    reg [3:0] min_tens, min_ones;
    reg [3:0] sec_tens, sec_ones;

    wire tick_en = run_en && !set_mode && tick_1hz;
    wire inc_hour = set_mode && pulse_rise && (sel == 2'd0);
    wire inc_min  = set_mode && pulse_rise && (sel == 2'd1);
    wire inc_sec  = set_mode && pulse_rise && (sel == 2'd2);

    wire sec_ones_max = (sec_ones == 4'd9);
    wire sec_tens_max = (sec_tens == 4'd5);
    wire min_ones_max = (min_ones == 4'd9);
    wire min_tens_max = (min_tens == 4'd5);
    wire hour_ones_max = (hour_tens == 4'd2) ? (hour_ones == 4'd3) : (hour_ones == 4'd9);
    wire hour_is_23 = (hour_tens == 4'd2) && (hour_ones == 4'd3);

    wire en_sec = tick_en | inc_sec;
    wire carry_sec_ones = en_sec & sec_ones_max;
    wire carry_sec = carry_sec_ones & sec_tens_max;

    wire en_min = carry_sec | inc_min;
    wire carry_min_ones = en_min & min_ones_max;
    wire carry_min = carry_min_ones & min_tens_max;

    wire en_hour = carry_min | inc_hour;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            set_mode <= 1'b0;
            sel <= 2'd0;
            run_en <= 1'b1;
            hour_tens <= 4'd0;
            hour_ones <= 4'd0;
            min_tens <= 4'd0;
            min_ones <= 4'd0;
            sec_tens <= 4'd0;
            sec_ones <= 4'd0;
        end else begin
            if (start_rise && !set_mode) begin
                run_en <= ~run_en;
            end

            if (stop_rise) begin
                set_mode <= ~set_mode;
                sel <= 2'd0;
            end

            if (set_mode && start_rise) begin
                if (sel == 2'd2) sel <= 2'd0;
                else sel <= sel + 2'd1;
            end

            if (en_sec) begin
                if (sec_ones_max) sec_ones <= 4'd0;
                else sec_ones <= sec_ones + 4'd1;
            end

            if (carry_sec_ones) begin
                if (sec_tens_max) sec_tens <= 4'd0;
                else sec_tens <= sec_tens + 4'd1;
            end

            if (en_min) begin
                if (min_ones_max) min_ones <= 4'd0;
                else min_ones <= min_ones + 4'd1;
            end

            if (carry_min_ones) begin
                if (min_tens_max) min_tens <= 4'd0;
                else min_tens <= min_tens + 4'd1;
            end

            if (en_hour) begin
                if (hour_is_23) begin
                    hour_tens <= 4'd0;
                    hour_ones <= 4'd0;
                end else if (hour_ones_max) begin
                    hour_ones <= 4'd0;
                    hour_tens <= hour_tens + 4'd1;
                end else begin
                    hour_ones <= hour_ones + 4'd1;
                end
            end
        end
    end

    always @(*) begin
        case (sec_ones)
            4'd0: seg_state = 7'b1111110;
            4'd1: seg_state = 7'b0110000;
            4'd2: seg_state = 7'b1101101;
            4'd3: seg_state = 7'b1111001;
            4'd4: seg_state = 7'b0110011;
            4'd5: seg_state = 7'b1011011;
            4'd6: seg_state = 7'b1011111;
            4'd7: seg_state = 7'b1110000;
            4'd8: seg_state = 7'b1111111;
            4'd9: seg_state = 7'b1111011;
            default: seg_state = 7'b0000000;
        endcase
    end

    assign lg2_pill_ones = sec_tens;
    assign lg3_pill_tens = min_ones;
    assign lg4_bot_ones  = min_tens;
    assign lg5_bot_tens  = hour_ones;
    assign lg6_bot_hund  = hour_tens;

    assign alarm = set_mode ? blink : 1'b0;

endmodule
