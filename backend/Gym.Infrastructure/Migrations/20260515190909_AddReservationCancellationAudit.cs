using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Gym.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddReservationCancellationAudit : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CancellationReason",
                table: "SessionReservations",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancelledAt",
                table: "SessionReservations",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CancelledByUserId",
                table: "SessionReservations",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_SessionReservations_CancelledByUserId",
                table: "SessionReservations",
                column: "CancelledByUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_SessionReservations_Users_CancelledByUserId",
                table: "SessionReservations",
                column: "CancelledByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_SessionReservations_Users_CancelledByUserId",
                table: "SessionReservations");

            migrationBuilder.DropIndex(
                name: "IX_SessionReservations_CancelledByUserId",
                table: "SessionReservations");

            migrationBuilder.DropColumn(
                name: "CancellationReason",
                table: "SessionReservations");

            migrationBuilder.DropColumn(
                name: "CancelledAt",
                table: "SessionReservations");

            migrationBuilder.DropColumn(
                name: "CancelledByUserId",
                table: "SessionReservations");
        }
    }
}
